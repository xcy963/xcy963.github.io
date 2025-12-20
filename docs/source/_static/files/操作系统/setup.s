	.code16
# rewrite with AT&T syntax by falcon <wuzhangjin@gmail.com> at 081012
#
#	setup.s		(C) 1991 Linus Torvalds
#
# setup.s is responsible for getting the system data from the BIOS,
# and putting them into the appropriate places in system memory.
# both setup.s and system has been loaded by the bootblock.
#
# This code asks the bios for memory/disk/other parameters, and
# puts them in a "safe" place: 0x90000-0x901FF, ie where the
# boot-block used to be. It is then up to the protected mode
# system to read them from there before the area is overwritten
# for buffer-blocks.
#

# NOTE! These had better be the same as in bootsect.s!

	.equ INITSEG, 0x9000	# we move boot here - out of the way
	.equ SYSSEG, 0x1000	# system loaded at 0x10000 (65536).
	.equ SETUPSEG, 0x9020	# this is the current segment

	.global _start, begtext, begdata, begbss, endtext, enddata, endbss
	.text
	begtext:
	.data
	begdata:
	.bss
	begbss:
	.text

	ljmp $SETUPSEG, $_start	
_start:

# ok, the read went well so we get current cursor position and save it for
# posterity.这个部分是保存光标位置的

	mov	$INITSEG, %ax	# this is done in bootsect already, but...
	mov	%ax, %ds       #更新数据段寄存器,之后好定位变量
	mov	$0x03, %ah	# read cursor pos
	xor	%bh, %bh
	int	$0x10		# save it in known place, con_init fetches
	mov	%dx, %ds:0	# it from 0x90000.  #保存光标信息到0x90000(注意是要乘16的)
# Get memory size (extended mem, kB)

	mov	$0x88, %ah 
	int	$0x15
	mov	%ax, %ds:2  #内存大小放在0x90002

# Get video-card data:

	mov	$0x0f, %ah
	int	$0x10
	mov	%bx, %ds:4	# bh = display page
	mov	%ax, %ds:6	# al = video mode, ah = window width

# check for EGA/VGA and some config parameters

	mov	$0x12, %ah
	mov	$0x10, %bl
	int	$0x10
	mov	%ax, %ds:8
	mov	%bx, %ds:10
	mov	%cx, %ds:12

# Get hd0 data

	mov	$0x0000, %ax
	mov	%ax, %ds
	lds	%ds:4*0x41, %si
	mov	$INITSEG, %ax
	mov	%ax, %es
	mov	$0x0080, %di
	mov	$0x10, %cx
	rep
	movsb

# Get hd1 data

	mov	$0x0000, %ax
	mov	%ax, %ds
	lds	%ds:4*0x46, %si
	mov	$INITSEG, %ax
	mov	%ax, %es
	mov	$0x0090, %di
	mov	$0x10, %cx
	rep
	movsb

# Check that there IS a hd1 :-)反正就是看有没有第二个硬盘,无所谓了

	mov	$0x01500, %ax
	mov	$0x81, %dl
	int	$0x13
	jc	no_disk1
	cmp	$3, %ah
	je	xcy_heck #直接入侵,这样就不会加载linux了
no_disk1:
	mov	$INITSEG, %ax
	mov	%ax, %es
	mov	$0x0090, %di
	mov	$0x10, %cx
	mov	$0x00, %ax
	rep
	stosb

xcy_heck:
    call    show_info

hang:
    hlt
    jmp     hang #写死循环
	
is_disk1:

# now we want to move to protected mode ...

	cli			# no interrupts allowed ! 

# first we move the system to it's rightful place

	mov	$0x0000, %ax
	cld			# 'direction'=0, movs moves forward
do_move:
	mov	%ax, %es	# destination segment
	add	$0x1000, %ax
	cmp	$0x9000, %ax
	jz	end_move
	mov	%ax, %ds	# source segment
	sub	%di, %di
	sub	%si, %si
	mov 	$0x8000, %cx
	rep
	movsw
	jmp	do_move

# then we load the segment descriptors

end_move:
	mov	$SETUPSEG, %ax	# right, forgot this at first. didn't work :-)
	mov	%ax, %ds
	lidt	idt_48		# load idt with 0,0
	lgdt	gdt_48		# load gdt with whatever appropriate

# that was painless, now we enable A20

	#call	empty_8042	# 8042 is the keyboard controller
	#mov	$0xD1, %al	# command write
	#out	%al, $0x64
	#call	empty_8042
	#mov	$0xDF, %al	# A20 on
	#out	%al, $0x60
	#call	empty_8042
	inb     $0x92, %al	# open A20 line(Fast Gate A20).
	orb     $0b00000010, %al
	outb    %al, $0x92

# well, that went ok, I hope. Now we have to reprogram the interrupts :-(
# we put them right after the intel-reserved hardware interrupts, at
# int 0x20-0x2F. There they won't mess up anything. Sadly IBM really
# messed this up with the original PC, and they haven't been able to
# rectify it afterwards. Thus the bios puts interrupts at 0x08-0x0f,
# which is used for the internal hardware interrupts as well. We just
# have to reprogram the 8259's, and it isn't fun.

	mov	$0x11, %al		# initialization sequence(ICW1)
					# ICW4 needed(1),CASCADE mode,Level-triggered
	out	%al, $0x20		# send it to 8259A-1
	.word	0x00eb,0x00eb		# jmp $+2, jmp $+2
	out	%al, $0xA0		# and to 8259A-2
	.word	0x00eb,0x00eb
	mov	$0x20, %al		# start of hardware int's (0x20)(ICW2)
	out	%al, $0x21		# from 0x20-0x27
	.word	0x00eb,0x00eb
	mov	$0x28, %al		# start of hardware int's 2 (0x28)
	out	%al, $0xA1		# from 0x28-0x2F
	.word	0x00eb,0x00eb		#               IR 7654 3210
	mov	$0x04, %al		# 8259-1 is master(0000 0100) --\
	out	%al, $0x21		#				|
	.word	0x00eb,0x00eb		#			 INT	/
	mov	$0x02, %al		# 8259-2 is slave(       010 --> 2)
	out	%al, $0xA1
	.word	0x00eb,0x00eb
	mov	$0x01, %al		# 8086 mode for both
	out	%al, $0x21
	.word	0x00eb,0x00eb
	out	%al, $0xA1
	.word	0x00eb,0x00eb
	mov	$0xFF, %al		# mask off all interrupts for now
	out	%al, $0x21
	.word	0x00eb,0x00eb
	out	%al, $0xA1

# well, that certainly wasn't fun :-(. Hopefully it works, and we don't
# need no steenking BIOS anyway (except for the initial loading :-).
# The BIOS-routine wants lots of unnecessary data, and it's less
# "interesting" anyway. This is how REAL programmers do it.
#
# Well, now's the time to actually move into protected mode. To make
# things as simple as possible, we do no register set-up or anything,
# we let the gnu-compiled 32-bit programs do that. We just jump to
# absolute address 0x00000, in 32-bit protected mode.
	#mov	$0x0001, %ax	# protected mode (PE) bit
	#lmsw	%ax		# This is it!
	mov	%cr0, %eax	# get machine status(cr0|MSW)	
	bts	$0, %eax	# turn on the PE-bit 
	mov	%eax, %cr0	# protection enabled
				
				# segment-descriptor        (INDEX:TI:RPL)
	.equ	sel_cs0, 0x0008 # select for code segment 0 (  001:0 :00) 
	ljmp	$sel_cs0, $0	# jmp offset 0 of code segment 0 in gdt

# This routine checks that the keyboard command queue is empty
# No timeout is used - if this hangs there is something wrong with
# the machine, and we probably couldn't proceed anyway.
empty_8042:
	.word	0x00eb,0x00eb
	in	$0x64, %al	# 8042 status port
	test	$2, %al		# is input buffer full?
	jnz	empty_8042	# yes - loop
	ret

#从这里开始是xcy加进去的

# putc: 打印al中的字符,一次打印一个,
putc:

    # 读光标位置（BH=页号=0）

    movb    $0x03, %ah
    xorb    %bh, %bh
    int     $0x10             # DH=row, DL=col

    # 写字符+属性（不自动移动光标）
    movb    $0x09, %ah
    mov	    $0x000C, %bx        # attribute：0x0C=黑底亮红字
    movw    $1, %cx
    int     $0x10

    # 光标前移一格,这个去掉会有问it
    incb    %dl
    movb    $0x02, %ah
    xorb    %bh, %bh
    int     $0x10

    ret

# print "\r\n"这两个字符使用普通模式,不然会乱码逆天
print_nl:
    pushw   %ax
    movb    $'\r', %al
    movb    $0x0E, %ah
    xorb    %bh, %bh
    int     $0x10

    movb    $'\n', %al
    movb    $0x0E, %ah
    xorb    %bh, %bh
    int     $0x10

    popw    %ax
    ret

# 打印字符串,字符串一定要以0结尾不然会死循环
print_string:
    pushw   %ax
1:
    lodsb                   # AL = [DS:SI], SI++
    testb   %al, %al        #按位与操作,判断是不是0
    jz      2f
    call    putc
    jmp     1b
2:
    popw    %ax
    ret

# 转化为ascii码,不然打印出来不是整数
print_hex_nibble:
    andb    $0x0F, %al
    cmpb    $9, %al
    jbe     1f
    addb    $('A' - 10), %al
    jmp     2f
1:
    addb    $'0', %al
2:
    call    putc
    ret

# 打印AL的1个字节
print_hex8:
    pushw   %ax
    movb    %al, %ah
    shrb    $4, %ah
    movb    %ah, %al
    call    print_hex_nibble
    popw    %ax
    call    print_hex_nibble
    ret

# 打印AX的2个字节
print_hex16:
    pushw   %ax
    movb    %ah, %al
    call    print_hex8
    popw    %ax
    call    print_hex8
    ret

# 以字节为单位打印好多16进制的字符
dump_16_bytes:
    pushw   %ax
    pushw   %cx
    movw    $0x10, %cx
1:
    lodsb
    call    print_hex8
    movb    $' ', %al
    call    putc
    loop    1b
    call    print_nl
    popw    %cx
    popw    %ax
    ret


# 打印之前保存的信息
show_info:
    pushw   %ax
    pushw   %bx
    pushw   %cx
    pushw   %dx
    pushw   %si
    pushw   %ds
    pushw   %es

    pushw   %cs
    popw    %ds              # DS = CS，用于访问 msg_xxx 字符串

    movw    $INITSEG, %ax
    movw    %ax, %es          # ES = 0x9000，用于访问 0x90000 的 BIOS 数据区

    #打印提示词
    movw    $msg1, %si
    call    print_string
    call    print_nl

    # Cursor
    movw    $msg_cursor, %si
    call    print_string
    movw    %es:0, %dx        # 注意：从 ES:0 取数据，而不是 DS:0

    movb    %dh, %al          # row
    call    print_hex8
    movb    $':', %al
    call    putc
    movb    %dl, %al          # col
    call    print_hex8
    call    print_nl

    # Extended memory (KB)
    movw    $msg_mem, %si
    call    print_string
    movw    %es:2, %ax
    call    print_hex16
    call    print_nl

    # Video
    movw    $msg_video, %si
    call    print_string

    movw    %es:4, %bx        
    movw    %es:6, %ax        # AL=mode, AH=cols

    movb    $'P', %al
    call    putc
    movb    $'=', %al
    call    putc
    movb    %bh, %al
    call    print_hex8
    movb    $' ', %al         
    call    putc

    movb    $'M', %al
    call    putc
    movb    $'=', %al
    call    putc
    movw    %es:6, %ax
    call    print_hex8         # AL=mode
    movb    $' ', %al
    call    putc

    movb    $'W', %al
    call    putc
    movb    $'=', %al
    call    putc
    movw    %es:6, %ax
    movb    %ah, %al           # cols
    call    print_hex8
    call    print_nl

    # EGA/VGA AX BX CX
    movw    $msg_ega, %si
    call    print_string
    movw    %es:8, %ax
    call    print_hex16
    movb    $' ', %al
    call    putc
    movw    %es:10, %ax
    call    print_hex16
    movb    $' ', %al
    call    putc
    movw    %es:12, %ax
    call    print_hex16
    call    print_nl

    # HD0 table
    movw    $msg_hd0, %si
    call    print_string
    movw    $0x0080, %si
    pushw   %ds

    pushw   %es
	popw    %ds           # dump_16_bytes 用 DS:SI，所以临时 DS=ES

    call    dump_16_bytes
    popw    %ds

    # HD1 table
    movw    $msg_hd1, %si
    call    print_string
    movw    $0x0090, %si
    pushw   %ds
    pushw   %es
	popw    %ds

    call    dump_16_bytes
    popw    %ds

    popw    %es
    popw    %ds
    popw    %si
    popw    %dx
    popw    %cx
    popw    %bx
    popw    %ax
    ret

#打印的字符
msg_cursor: .ascii "Cursor row:col = 0x\0"
msg_mem:    .ascii "ExtMem(KB) = 0x\0"
msg_video:  .ascii "Video: \0"
msg_ega:    .ascii "EGA/VGA AX BX CX = \0"
msg_hd0:    .ascii "HD0 table(16B) = \0"
msg_hd1:    .ascii "HD1 table(16B) = \0"


msg1:
	.ascii "Now we are in SETUP\0"

gdt:
	.word	0,0,0,0		# dummy

	.word	0x07FF		# 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		# base address=0
	.word	0x9A00		# code read/exec
	.word	0x00C0		# granularity=4096, 386

	.word	0x07FF		# 8Mb - limit=2047 (2048*4096=8Mb)
	.word	0x0000		# base address=0
	.word	0x9200		# data read/write
	.word	0x00C0		# granularity=4096, 386

idt_48:
	.word	0			# idt limit=0
	.word	0,0			# idt base=0L

gdt_48:
	.word	0x800			# gdt limit=2048, 256 GDT entries
	.word   512+gdt, 0x9		# gdt base = 0X9xxxx, 
	# 512+gdt is the real gdt after setup is moved to 0x9020 * 0x10
	
.text
endtext:
.data
enddata:
.bss
endbss:
