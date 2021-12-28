if ($env:COMPUTERNAME -ne 'dc2') {
    Rename-Computer -NewName dc2 -Force    
}

