import cv2
import os
import sys

def resize_texture(image_path, output_path, new_width=None, new_height=None, scale_factor=None):
    """
    使用OpenCV缩放Live2D模型贴图
    
    参数:
        image_path (str): 原始贴图文件路径
        output_path (str): 缩放后贴图保存路径
        new_width (int, optional): 新的宽度（像素）
        new_height (int, optional): 新的高度（像素）
        scale_factor (float, optional): 缩放比例，例如0.5表示缩小一半
    """
    # 读取图片
    img = cv2.imread(image_path, cv2.IMREAD_UNCHANGED)  # 保留Alpha通道
    
    if img is None:
        print(f"错误：无法读取图片 '{image_path}'")
        return False
    
    original_height, original_width = img.shape[:2]
    print(f"原始贴图尺寸: {original_width} x {original_height}")
    
    # 计算目标尺寸
    if new_width is not None and new_height is not None:
        # 直接使用指定的宽度和高度
        target_width = new_width
        target_height = new_height
    elif scale_factor is not None:
        # 使用缩放比例
        target_width = int(original_width * scale_factor)
        target_height = int(original_height * scale_factor)
    else:
        print("错误：请指定 new_width 和 new_height，或者 scale_factor")
        return False
    
    print(f"目标贴图尺寸: {target_width} x {target_height}")
    
    # 使用INTER_AREA插值方法进行缩小（如果是放大则使用INTER_LINEAR）
    interpolation = cv2.INTER_AREA if target_width < original_width else cv2.INTER_LINEAR
    
    # 缩放图片
    resized_img = cv2.resize(img, (target_width, target_height), interpolation=interpolation)
    
    # 保存图片（保留PNG格式和Alpha通道）
    success = cv2.imwrite(output_path, resized_img, [cv2.IMWRITE_PNG_COMPRESSION, 5])
    
    if success:
        print(f"成功保存缩放后的贴图: {output_path}")
        
        # 计算文件大小变化
        original_size = os.path.getsize(image_path) / 1024  # KB
        new_size = os.path.getsize(output_path) / 1024  # KB
        
        print(f"文件大小变化: {original_size:.2f}KB -> {new_size:.2f}KB")
        return True
    else:
        print(f"错误：保存图片失败 '{output_path}'")
        return False

def main():
    # 配置参数 - 根据您的需求修改这些值
    for index in range(6):

        original_texture = f"texture_0{index}.png"           # 原始贴图文件名
        output_texture = original_texture     # 输出贴图文件名
        # 缩放方式选择其一：
        # 方式1: 直接指定新尺寸
        new_width = 1024     # 例如缩小到2048x2048
        new_height = 1024
        
        # 方式2: 或者使用缩放比例
        # scale_factor = 0.5  # 缩小到50%
        
        # 执行缩放
        success = resize_texture(
            image_path=original_texture,
            output_path=output_texture,
            new_width=new_width,
            new_height=new_height
            # scale_factor=scale_factor  # 取消注释使用缩放比例方式
        )
        
        if success:
            print("\n贴图缩放完成！")
            print("重要提醒：")
            print("1. 请备份原始贴图文件")
            print("2. 您需要手动更新模型文件引用或重命名文件")
        else:
            print("\n贴图缩放失败！")

if __name__ == "__main__":
    main()