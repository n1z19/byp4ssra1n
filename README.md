# byp4ssra1n
jump setup on dualbooted devices and downgraded for ios 15, 14, 13

# Usage

Example: ./byp4ssra1n.sh --tethered 14.3 for downr1n or normal ios

example ./byp4ssra1n.sh --dualboot 14.3 for dualra1n

Options: 
   --dualboot          if you want bypass icloud in the dualboot use this ./byp4ssra1n.sh --dualboot 14.3
   
    --jail_palera1n   Use this only when you already jailbroken with semitethered palera1n to avoid disk errors. ./byp4ssra1n.sh
    
    --dualboot 14.3  --jail_palera1n 
    
    --tethered            to bypass main ios, use this if you have checkra1n or palera1n tethered jailbreak (the device will bootloop if you try to boot without jailbreak). ./
    byp4ssra1n.sh --tethered 14.3

    --backup-activations    this command will save your activations files into activationsBackup/. so later you can restore them
    --restore-activations   this command will put your activations files into the device.

    --back              if you want to bring back i cloud you can use for example ./byp4ssra1n.sh    --tethered 14.3 --back (tethered you can change to kind of jailbreak like --semitethered or --dualboot)

    --dfuhelper         A helper to help get A11 devices into DFU mode from recovery mode
    --debug             Debug the script


_ _ _


# or you can use the gui version, python3 gui.py

- depend of PyQt5, pip3 install PyQt5


# Credits

- [palera1n](https://github.com/palera1n) for some of the code

- [verygenericname](https://github.com/verygenericname) for the cool SSH Ramdisk

- [Brayan-Villa](https://github.com/Brayan-Villa/iOS15-Bypass-Hello) for the amazing idea

- [Divise](https://github.com/MatthewPierson/Divise) thank you for the mobileactivationd

-  [RIFOX], THANK YOU FOR THE GUI.
