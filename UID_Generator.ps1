# Function to generate a 10-digit UID with a letter followed by 9 random digits
function Generate-UID {
    param (
        [string]$fileTypeLetter
    )
    # Generate 9 random digits
    $randomDigits = (1..9 | ForEach-Object { Get-Random -Minimum 0 -Maximum 9 }) -join ''
    # Combine the letter and the random digits to create the UID
    return $fileTypeLetter + $randomDigits
}

# Step 1: Request the file path
$filePath = Read-Host "Please enter the folder path"

# Check if the provided path exists
if (!(Test-Path -Path $filePath)) {
    Write-Host "The provided path does not exist."
    return
}

# Get all files in the specified folder
$files = Get-ChildItem -Path $filePath -File

# Initialize a hash table to store user input for each file
$fileTypes = @{}

# Step 2: Define file type options
$fileTypeMessage = @"
Please specify the file type for each file:
R = Report
D = Document
I = Instruction
O = Order
A = Artefact
M = Miscellaneous

"@

# Step 3: Loop through each file and get the file type from the user
foreach ($file in $files) {
    Write-Host "Processing file: $($file.Name)"
    $userInput = Read-Host "$fileTypeMessage"

    # Validate user input to ensure it matches one of the expected letters
    while ($userInput -notin 'R','D','I','O','A','M') {
        Write-Host "Invalid input. Please enter one of the following letters: R, D, I, O, A, M."
        $userInput = Read-Host "$fileTypeMessage"
    }

    # Store the user input for this file
    $fileTypes[$file.Name] = $userInput
}

# Step 4: Append a UID to each file based on the user's input
foreach ($file in $files) {
    $fileType = $fileTypes[$file.Name]
    $uid = Generate-UID -fileTypeLetter $fileType

    # Build the new file name with the UID appended before the extension
    $fileExtension = $file.Extension
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $newFileName = "$baseName-$uid$fileExtension"

    # Rename the file with the new name
    $newFilePath = Join-Path -Path $file.DirectoryName -ChildPath $newFileName
    Rename-Item -Path $file.FullName -NewName $newFileName
}

Write-Host "Files have been renamed with the UID appended successfully."
