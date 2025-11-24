import cv2
import os
import argparse
import cv2
import os
import argparse

def convert_to_jpg(input_folder, output_folder=None, quality=95, preserve_structure=True):
    """
    将指定文件夹及其所有子文件夹中的图片转换为 JPG 格式
    
    参数:
        input_folder (str): 输入图片所在的根文件夹路径
        output_folder (str): 输出文件夹路径，默认为输入文件夹下的 'jpg_output' 文件夹
        quality (int): JPG 图片质量，范围 0-100，默认为 95
        preserve_structure (bool): 是否在输出中保持原始文件夹结构，默认为 True
    """
    # 设置输出文件夹
    if output_folder is None:
        output_folder = os.path.join(input_folder, 'jpg_output')
    
    # 创建输出文件夹（如果不存在）
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
        print(f"创建输出目录: {output_folder}")
    
    # 支持的图片格式
    supported_formats = {'.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.tif', '.webp'}
    
    # 转换计数器
    success_count = 0
    fail_count = 0
    
    print("开始遍历文件夹并转换图片...")
    
    # 使用 os.walk 递归遍历所有子文件夹[2,4,7](@ref)
    for root, dirs, files in os.walk(input_folder):
        # 计算当前文件夹在输出目录中的对应路径
        if preserve_structure:
            # 保持原始文件夹结构
            relative_path = os.path.relpath(root, input_folder)
            # 处理当前文件夹是输入文件夹本身的情况
            if relative_path == '.':
                current_output_folder = output_folder
            else:
                current_output_folder = os.path.join(output_folder, relative_path)
            
            # 确保输出子文件夹存在
            if not os.path.exists(current_output_folder):
                os.makedirs(current_output_folder)
        else:
            # 不保持文件夹结构，所有图片直接放在输出文件夹中
            current_output_folder = output_folder
    
        # 遍历当前文件夹中的所有文件
        for filename in files:
            # 检查文件扩展名
            file_ext = os.path.splitext(filename)[1].lower()
            if file_ext in supported_formats:
                input_path = os.path.join(root, filename)
                
                # 生成输出文件名（保持原文件名，只改变扩展名）
                name_without_ext = os.path.splitext(filename)[0]
                output_filename = f"{name_without_ext}.jpg"
                output_path = os.path.join(current_output_folder, output_filename)
                
                # 如果输出文件已存在，跳过转换
                if os.path.exists(output_path):
                    print(f"⚠ 文件已存在，跳过: {output_filename}")
                    continue
                
                try:
                    # 读取图片
                    img = cv2.imread(input_path)
                    
                    if img is None:
                        print(f"警告：无法读取图片 '{input_path}'，跳过")
                        fail_count += 1
                        continue
                    
                    # 设置 JPG 编码参数（质量）
                    jpg_params = [cv2.IMWRITE_JPEG_QUALITY, quality]
                    
                    # 保存为 JPG 格式
                    success = cv2.imwrite(output_path, img, jpg_params)
                    
                    if success:
                        # 获取文件大小信息
                        input_size = os.path.getsize(input_path)
                        output_size = os.path.getsize(output_path)
                        size_ratio = (output_size / input_size) * 100
                        
                        # 显示相对路径，使输出更简洁
                        display_path = os.path.join(os.path.basename(root), filename) if root != input_folder else filename
                        print(f"✓ 转换成功: {display_path} → {output_filename} ({size_ratio:.1f}% 原大小)")
                        success_count += 1
                    else:
                        print(f"✗ 转换失败: {filename}")
                        fail_count += 1
                        
                except Exception as e:
                    print(f"✗ 处理图片 '{filename}' 时出错: {str(e)}")
                    fail_count += 1
    
    # 输出转换结果摘要
    print("\n" + "="*50)
    print("转换完成！")
    print(f"成功: {success_count} 张")
    print(f"失败: {fail_count} 张")
    print(f"输出目录: {output_folder}")
    if preserve_structure:
        print("文件夹结构已保持")
def main():
    """主函数，支持命令行参数"""
    parser = argparse.ArgumentParser(description='将图片批量转换为 JPG 格式')
    parser.add_argument('input_folder', help='输入图片所在的文件夹路径')
    parser.add_argument('-o', '--output', dest='output_folder', 
                       help='输出文件夹路径（可选）')
    parser.add_argument('-q', '--quality', type=int, default=95,
                       help='JPG 图片质量 (0-100，默认: 95)')
    
    args = parser.parse_args()
    
    # 验证质量参数
    if not 0 <= args.quality <= 100:
        print("错误：质量参数必须在 0-100 之间")
        return
    
    # 执行转换
    convert_to_jpg(args.input_folder, args.output_folder, args.quality)

# 直接使用示例
if __name__ == "__main__":
    # 方法1: 直接指定参数调用
    input_dir = "./docs/source/_static/img"  # 请替换为你的图片文件夹路径
    output_dir = "./docs/source/_static/img"      # 请替换为你的输出文件夹路径（可选）
    
    # 取消下面的注释来直接运行
    convert_to_jpg(input_dir, output_dir, quality=95)
    
    # 方法2: 使用命令行参数（取消下面一行的注释）
    # main()