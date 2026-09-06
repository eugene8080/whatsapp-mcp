# Same as start-all.ps1, without the console window. See that file for why the bot line is gone.
Start-Process pwsh -ArgumentList '-NoExit', '-Command', 'cd D:\dev\whatsapp-mcp\whatsapp-bridge; .\whatsapp-bridge.exe' -WindowStyle Hidden
