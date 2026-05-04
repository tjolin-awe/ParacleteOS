$disk = New-Object byte[] 1474560
$boot = [System.IO.File]::ReadAllBytes('boot.bin')
$kernel = [System.IO.File]::ReadAllBytes('kernel.bin')

# --- Existing Copy Logic ---
[Array]::Copy($boot, 0, $disk, 0, $boot.Length)
[Array]::Copy($kernel, 0, $disk, 512, $kernel.Length)

# --- Directory Entries (Sector 6) ---
$dirOffset = 512 * 5

# Entry 1: BOOT.BIN (Sector 1)
$name1 = [System.Text.Encoding]::ASCII.GetBytes("BOOT    BIN")
[Array]::Copy($name1, 0, $disk, $dirOffset, 11)
$disk[$dirOffset + 26] = 1 # Start Sector

# Entry 2: KERNEL.BIN (Sector 2)
$name2 = [System.Text.Encoding]::ASCII.GetBytes("KERNEL  BIN")
[Array]::Copy($name2, 0, $disk, $dirOffset + 32, 11)
$disk[$dirOffset + 32 + 26] = 2 # Start Sector

# Entry 3: HELLO.TXT (Sector 7)
$name3 = [System.Text.Encoding]::ASCII.GetBytes("HELLO   TXT")
[Array]::Copy($name3, 0, $disk, $dirOffset + 64, 11)
$disk[$dirOffset + 64 + 26] = 7 # Start Sector

# --- File Contents ---
$fileOffset = 512 * 6 # Sector 7
$content = [System.Text.Encoding]::ASCII.GetBytes("Hello, world!")
[Array]::Copy($content, 0, $disk, $fileOffset, $content.Length)

[System.IO.File]::WriteAllBytes('os.img', $disk)