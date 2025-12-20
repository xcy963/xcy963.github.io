	.code16
# rewrite with AT&T syntax by falcon <wuzhangjin@gmail.com> at 081012
#
# SYS_SIZE is the number of clicks (16 bytes) to be loaded.
# 0x3000 is 0x30000 bytes = 196kB, more than enough for current
# versions of linux
#
	.equ SYSSIZE, 0x3000
#
#	bootsect.s		(C) 1991 Linus Torvalds
#
# bootsect.s is loaded at 0x7c00 by the bios-startup routines, and moves
# iself out of the way to address 0x90000, and jumps there.
#
# It then loads 'setup' directly after itself (0x90200), and the system
# at 0x10000, using BIOS interrupts. 
#
# NOTE! currently system is at most 8*65536 bytes long. This should be no
# problem, even in the future. I want to keep it simple. This 512 kB
# kernel size should be enough, especially as this doesn't contain the
# buffer cache as in minix
#
# The loader has been made as simple as possible, and continuos
# read errors will result in a unbreakable loop. Reboot by hand. It
# loads pretty fast by getting whole sectors at a time whenever possible.

	.global _start, begtext, begdata, begbss, endtext, enddata, endbss
	.text
	begtext:
	.data
	begdata:
	.bss
	begbss:
	.text

	.equ SETUPLEN, 4		# nr of setup-sectors
	.equ BOOTSEG, 0x07c0		# original address of boot-sector
	.equ INITSEG, 0x9000		# we move boot here - out of the way
	.equ SETUPSEG, 0x9020		# setup starts here
	.equ SYSSEG, 0x1000		# system loaded at 0x10000 (65536).
	.equ ENDSEG, SYSSEG + SYSSIZE	# where to stop loading

# ROOT_DEV:	0x000 - same type of floppy as boot.
#		0x301 - first partition on first drive etc
	.equ ROOT_DEV, 0x301
	ljmp    $BOOTSEG, $_start #cs变为BOOTSEG,eip变为_start,
_start:
	mov	$BOOTSEG, %ax
	mov	%ax, %ds     #复制指令.  的原始段是ds
	mov	$INITSEG, %ax  
	mov	%ax, %es     #复制指令的目标段是es
	mov	$256, %cx    #重复的计数器
	sub	%si, %si     #复制的起始内存使用DS:SI,所以这里清零si
	sub	%di, %di     # 清di
	rep	             #让movsw执行cx次,所以是从0x7c00搬256个字节到0x9000
	movsw		     
	ljmp	$INITSEG, $go  #跳转到0x9c00执行
go:	mov	%cs, %ax        #执行跳转cs现在是0x9c00 
	mov	%ax, %ds        #
	mov	%ax, %es
# put stack at 0x9ff00.
	mov	%ax, %ss            # 开栈空间,不大于512的话栈就把代码段覆盖了
	mov	$0xFF00, %sp		# arbitrary value >>512

# load the setup-sectors directly after the bootblock.
# Note that 'es' is already set up.
# load_setup利用bios中断int 0x13把setup.s从磁盘加载过来,本身bios只是帮我们加载了本文件对应的256B的代码

load_setup:
	mov	$0x0000, %dx		# drive 0, head 0 磁头,默认软盘A
	mov	$0x0002, %cx		# sector 2, track 0 
	mov	$0x0200, %bx		# address = 512, in INITSEG
	.equ    AX, 0x0200+SETUPLEN
	mov     $AX, %ax		# service 2, nr of sectors
	int	$0x13			# read it
	jnc	ok_load_setup		# ok - continue
	mov	$0x0000, %dx
	mov	$0x0000, %ax		# reset the diskette
	int	$0x13
	jmp	load_setup

# 我不管了,反正可以从磁盘读过来,他失败就一直重复读
ok_load_setup:

# Get disk drive parameters, specifically nr of sectors/track

	mov	$0x00, %dl        #选择驱动器号,A:软驱
	mov	$0x0800, %ax		# AH=8 is get drive parameters
	int	$0x13
	mov	$0x00, %ch
	#seg cs
	mov	%cx, %cs:sectors+0	# %cs means sectors is in %cs,估计是存在这了
	mov	$INITSEG, %ax  
	mov	%ax, %es  #打印字符串使用?

# Print some inane message

#	mov	$0x03, %ah		# read cursor pos
#	xor	%bh, %bh
#	int	$0x10          #读取光标位置的中断
#	
#	mov	$24, %cx            #要打印的字符串的长度
#	mov	$0x0007, %bx		# page 0, attribute 7 (normal)字符的显示属性
#	#lea	msg1, %bp
#	mov     $msg1, %bp      #这个是下面写死的ascii字符串
#	mov	$0x1301, %ax		# write string, move cursor反正是参数,不管就好
#	int	$0x10 

	mov %cs, %ax
    mov %ax, %ds        # DS 等下要使用ds::si加载logo
    mov $logo, %si      # SI 
    call print_logo


# ok, we've written the message, now
# we want to load the system (at 0x10000)

	mov	$SYSSEG, %ax
	mov	%ax, %es		# segment of 0x010000
	call	read_it
	call	kill_motor
#操作系统被读到0x1000了,磁盘电机也关闭了,现在准备跳转执行操作系统
# After that we check which root-device to use. If the device is
# defined (#= 0), nothing is done and the given device is used.
# Otherwise, either /dev/PS0 (2,28) or /dev/at0 (2,8), depending
# on the number of sectors that the BIOS reports currently.

	#seg cs
	mov	%cs:root_dev+0, %ax
	cmp	$0, %ax
	jne	root_defined
	#seg cs
	mov	%cs:sectors+0, %bx
	mov	$0x0208, %ax		# /dev/ps0 - 1.2Mb
	cmp	$15, %bx
	je	root_defined
	mov	$0x021c, %ax		# /dev/PS0 - 1.44Mb
	cmp	$18, %bx
	je	root_defined
undef_root:
	jmp undef_root
root_defined:
	#seg cs
	mov	%ax, %cs:root_dev+0  #反正就是把磁盘设备号放到%cs:root_dev+0 ,这样之后就知道/根目录在哪里了

# after that (everyting loaded), we jump to
# the setup-routine loaded directly after
# the bootblock:

	ljmp	$SETUPSEG, $0  

# This routine loads the system at address 0x10000, making sure
# no 64kB boundaries are crossed. We try to load it as fast as
# possible, loading whole tracks whenever we can.
#
# in:	es - starting address segment (normally 0x1000)
#
sread:	.word 1+ SETUPLEN	# sectors read of current track
head:	.word 0			# current head
track:	.word 0			# current track

#反正就是读到0x1000,不看不看
read_it:
	mov	%es, %ax              #刚设置的0x1000
	test	$0x0fff, %ax
die:	jne 	die			# es must be at 64kB boundary
	xor 	%bx, %bx		# bx is starting address within segment,就是设置0被
rp_read:
	mov 	%es, %ax
 	cmp 	$ENDSEG, %ax		# have we loaded all yet?
	jb	ok1_read
	ret
ok1_read:
	#seg cs
	mov	%cs:sectors+0, %ax
	sub	sread, %ax
	mov	%ax, %cx
	shl	$9, %cx
	add	%bx, %cx
	jnc 	ok2_read
	je 	ok2_read
	xor 	%ax, %ax
	sub 	%bx, %ax
	shr 	$9, %ax
ok2_read:
	call 	read_track
	mov 	%ax, %cx
	add 	sread, %ax
	#seg cs
	cmp 	%cs:sectors+0, %ax
	jne 	ok3_read
	mov 	$1, %ax
	sub 	head, %ax
	jne 	ok4_read
	incw    track 
ok4_read:
	mov	%ax, head
	xor	%ax, %ax
ok3_read:
	mov	%ax, sread
	shl	$9, %cx
	add	%cx, %bx
	jnc	rp_read
	mov	%es, %ax
	add	$0x1000, %ax
	mov	%ax, %es
	xor	%bx, %bx
	jmp	rp_read

read_track:
	push	%ax
	push	%bx
	push	%cx
	push	%dx
	mov	track, %dx
	mov	sread, %cx
	inc	%cx
	mov	%dl, %ch
	mov	head, %dx
	mov	%dl, %dh
	mov	$0, %dl
	and	$0x0100, %dx
	mov	$2, %ah
	int	$0x13
	jc	bad_rt
	pop	%dx
	pop	%cx
	pop	%bx
	pop	%ax
	ret
bad_rt:	mov	$0, %ax
	mov	$0, %dx
	int	$0x13
	pop	%dx
	pop	%cx
	pop	%bx
	pop	%ax
	jmp	read_track

#/*
# * This procedure turns off the floppy drive motor, so
# * that we enter the kernel in a known state, and
# * don't have to worry about it later.
# */
kill_motor:
	push	%dx
	mov	$0x3f2, %dx
	mov	$0, %al
	outsb
	pop	%dx
	ret

#打印fufu画像,他以0x00结尾,使用这个判断
print_logo:
    push %ax
    push %bx
    push %si
.next:
    lodsb               # AL = [DS:SI]
	#mov  $logo,%al
    test %al, %al
    je   .done
    mov  $0x0E, %ah      # teletype output
    xor  %bh, %bh        # page 0
    int  $0x10
    jmp  .next
.done:
    pop  %si
    pop  %bx
    pop  %ax
    ret

sectors:
	.word 0

logo:
    .byte 0xB1,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB1,0xB1,0xB2,0xB2,0xB2,0x0D,0x0A
    .byte 0xB1,0xB1,0xB1,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB1,0xB2,0xB2,0xB1,0xB1,0xB2,0x0D,0x0A
    .byte 0xB2,0xB2,0xB2,0xB1,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB1,0xB2,0xB2,0xB2,0xB2,0xB1,0x0D,0x0A
    .byte 0xB2,0xB2,0xB2,0xB2,0xB2,0xB1,0xB2,0xB2,0xB2,0xB2,0xB1,0xB2,0xB2,0xB2,0xB2,0xB2,0x0D,0x0A
    .byte 0xB2,0xB0,0xB1,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB1,0xB1,0xB2,0xB2,0xB1,0xB0,0xB1,0x0D,0x0A
    .byte 0xB1,0xB0,0xB1,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB2,0xB1,0xB0,0xB1,0x0D,0x0A
    #.byte 0x78,0x63,0x79,0x5F,0x66,0x75,0x66,0x75,0x7E,0x0D,0x0A
	.ascii "2023110264\r\n"
    .byte  0x00

#msg1:
#	.byte 13,10
#	.ascii "Loading system ..."
#	.byte 13,10,13,10

	.org 508
root_dev:
	.word ROOT_DEV
boot_flag:
	.word 0xAA55
	
	.text
	endtext:
	.data
	enddata:
	.bss
	endbss:
