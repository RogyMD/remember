📂 README – HippoCam App Files

This file explains how the HippoCam app stores your memories and how you can safely back them up or restore them if needed.

⚠️ Please do not manually edit or rename files or folders in this directory.
Doing so may cause the app to stop working properly or lose saved memories.

🛠 Backup Instructions:
1. Compress the "Memories" folder
2. Save the ZIP file in a safe place (e.g., iCloud, external drive)

🔄 Restore Instructions:
1. Uncompress your backup ZIP
2. Replace the existing "Memories" folder with the one from the backup

📁 Folder Structure Explained:
Each folder inside "Memories" represents a saved memory.

Folders are named like this:

{labels}_{id}_{date}_{time}
Ex. Label1-Label2_2025-05-31-19-00-00

Inside each memory folder:
- `original.png`: Full-resolution image
- `preview.png`: Scaled-down image for quick preview
- `thumbnail.png`: Small image used in lists or grids
- `memory.txt`: Contains all memory details:
  - labels/items
  - tags (if available)
  - notes (if available)
  - location (if available)
  - creation date
  - unique ID

More info at: https://rogy.app/hippocam

Thanks for using HippoCam!  
With love,  
Igor
