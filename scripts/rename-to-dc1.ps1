if ($env:COMPUTERNAME -ne 'dc1') {
    Rename-Computer -NewName dc1 -Force    
}

