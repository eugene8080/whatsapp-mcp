Start-Process pwsh -ArgumentList '-NoExit', '-Command', 'cd D:\dev\whatsapp-mcp\whatsapp-bridge; .\whatsapp-bridge.exe' -WindowStyle Hidden
Start-Process pwsh -ArgumentList '-NoExit', '-Command', 'cd D:\dev\whatsapp-mcp\whatsapp-bot; python bot.py' -WindowStyle Hidden
