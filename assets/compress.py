import argparse
import os
from PIL import Image

def compress_image(input_path, output_path, quality=85):
    """Compress an image and save it to the output path."""
    with Image.open(input_path) as img:
        # Convert to RGB if not already
        if img.mode != 'RGB':
            img = img.convert('RGB')
        # Save as JPEG with specified quality
        img.save(output_path, 'JPEG', quality=quality, optimize=True)
        print(f"Compressed and saved {input_path} to {output_path} with quality={quality}.")

def process_images(input_folder, output_folder, max_size_kb=500, quality=85):
    """Process images in the folder and compress those larger than max_size_kb."""
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
    
    for filename in os.listdir(input_folder):
        if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            input_path = os.path.join(input_folder, filename)
            output_path = os.path.join(output_folder, filename)
            
            # Check file size
            file_size_kb = os.path.getsize(input_path) / 1024
            print(f"Checking {filename}: {file_size_kb:.2f} KB")
            
            if file_size_kb > max_size_kb:
                print(f"Compressing {filename} ({file_size_kb:.2f} KB)")
                compress_image(input_path, output_path, quality)
            else:
                print(f"{filename} is already under the size limit ({file_size_kb:.2f} KB)")

def main():
    parser = argparse.ArgumentParser(description="Compress images in a folder based on file size.")
    parser.add_argument('input_folder', type=str, help="The input folder containing images to compress.")
    parser.add_argument('output_folder', type=str, help="The output folder to save compressed images.")
    parser.add_argument('--max_size_kb', type=int, default=500, help="Maximum file size in KB to trigger compression (default: 500).")
    parser.add_argument('--quality', type=int, default=85, help="Quality of the compressed images (default: 85).")
    
    args = parser.parse_args()

    process_images(args.input_folder, args.output_folder, args.max_size_kb, args.quality)

if __name__ == "__main__":
    main()
