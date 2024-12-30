#!/usr/bin/env bash

mkdir -p logs
mkdir -p boot
set -e

log="last".log
cd logs
touch "$log"
cd ..

{

echo "[*] Command ran:`if [ $EUID = 0 ]; then echo " sudo"; fi` ./bypassra1n.sh $@"

# =========
# Variables
# ========= 
version="3.0"
os=$(uname)
dir="$(pwd)/binaries/$os"
max_args=1
arg_count=0
disk=8

if [ ! -d "ramdisk/" ]; then
    git clone https://github.com/n1z19/ramdisk.git
fi
# =========
# Functions
# =========
remote_cmd() {
    sleep 1
    "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "$@"
}

remote_cp() {
    sleep 1
    "$dir"/sshpass -p 'alpine' scp -r -o StrictHostKeyChecking=no -P2222 $@
}

step() {
    rm -f .entered_dfu
    for i in $(seq "$1" -1 0); do
        if [[ -e .entered_dfu ]]; then
            rm -f .entered_dfu
            break
        fi
        if [[ $(get_device_mode) == "dfu" || ($1 == "10" && $(get_device_mode) != "none") ]]; then
            touch .entered_dfu
        fi &
        printf '\r\e[K\e[1;36m%s (%d)' "$2" "$i"
        sleep 1
    done
    printf '\e[0m\n'
}

print_help() {
    cat << EOF
Usage: $0 [Options] [ subcommand | on ios 15 you have to use palera1n to jailbreak it when you jailbreak it you can bypass it 
./byp4ssra1n.sh

Options:
    --dualboot              if you want bypass iCloud in the dualboot use this ./byp4ssra1n.sh --bypass 14.3 --dualboot
    --jail_palera1n         Use this only when you already jailbroken with Semi-Tethered palera1n to avoid disk errors on bypass dualboot. ./byp4ssra1n.sh --bypass 14.3 --dualboot --jail_palera1n
    --tethered              bypass the main ios 13,14,15, use this if you have checkra1n or palera1n tethered jailbreak or Semi-Tethered (the device will bootloop if you try to boot without jailbreak). ./bypassra1n.sh --bypass 14.3, also if you want to bring back icloud you can use ./byp4ssra1n.sh --bypass 14.3 --back
    --debug                 Debug the script
    --backup-activations    this command will save your activations files into activationsBackup/.
    --restore-activations   this command will put your activations files into the device.
Subcommands:
    clean               Deletes the created boot files


The iOS version argument should be the iOS version of your device.
It is required when starting from DFU mode.
EOF
}

parse_opt() {
    case "$1" in
        --)
            no_more_opts=1
            ;;
        --dualboot)
            dualboot=1
            ;;
        --tethered)
            tethered=1
            ;;
        --back)
            back=1
            ;;
        --jail_palera1n)
            jail_palera1n=1
            ;;
        --debug)
            debug=1
            ;;
        --backup-activations)
            backup_activations=1
            ;;
        --restore-activations)
            restore_activations=1
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo "[-] Unknown option $1. Use $0 --help for help."
            exit 1;
    esac
}

parse_arg() {
    arg_count=$((arg_count + 1))
    case "$1" in
        dfuhelper)
            dfuhelper=1
            ;;
        clean)
            clean=1
            ;;
        *)
            version="$1"
            ;;
    esac
}

parse_cmdline() {
    for arg in $@; do
        if [[ "$arg" == --* ]] && [ -z "$no_more_opts" ]; then
            parse_opt "$arg";
        elif [ "$arg_count" -lt "$max_args" ]; then
            parse_arg "$arg";
        else
            echo "[-] Too many arguments. Use $0 --help for help.";
            exit 1;
        fi
    done
}

recovery_fix_auto_boot() {
    "$dir"/irecovery -c "setenv auto-boot true"
    "$dir"/irecovery -c "saveenv"
}

_info() {
    if [ "$1" = 'recovery' ]; then
        echo $("$dir"/irecovery -q | grep "$2" | sed "s/$2: //")
    elif [ "$1" = 'normal' ]; then
        echo $("$dir"/ideviceinfo | grep "$2: " | sed "s/$2: //")
    fi
}

_pwn() {
    pwnd=$(_info recovery PWND)
    if [ "$pwnd" = "" ]; then
        echo "[*] Pwning device"
        "$dir"/gaster pwn
        sleep 2
        #"$dir"/gaster reset
        #sleep 1
    fi
}

_reset() {
        echo "[*] Resetting DFU state"
        "$dir"/gaster reset
}

get_device_mode() {
    if [ "$os" = "Darwin" ]; then
        sp="$(system_profiler SPUSBDataType 2> /dev/null)"
        apples="$(printf '%s' "$sp" | grep -B1 'Vendor ID: 0x05ac' | grep 'Product ID:' | cut -dx -f2 | cut -d' ' -f1 | tail -r)"
    elif [ "$os" = "Linux" ]; then
        apples="$(lsusb | cut -d' ' -f6 | grep '05ac:' | cut -d: -f2)"
    fi
    local device_count=0
    local usbserials=""
    for apple in $apples; do
        case "$apple" in
            12a8|12aa|12ab)
            device_mode=normal
            device_count=$((device_count+1))
            ;;
            1281)
            device_mode=recovery
            device_count=$((device_count+1))
            ;;
            1227)
            device_mode=dfu
            device_count=$((device_count+1))
            ;;
            1222)
            device_mode=diag
            device_count=$((device_count+1))
            ;;
            1338)
            device_mode=checkra1n_stage2
            device_count=$((device_count+1))
            ;;
            4141)
            device_mode=pongo
            device_count=$((device_count+1))
            ;;
        esac
    done
    if [ "$device_count" = "0" ]; then
        device_mode=none
    elif [ "$device_count" -ge "2" ]; then
        echo "[-] Please attach only one device" > /dev/tty
        kill -30 0
        exit 1;
    fi
    if [ "$os" = "Linux" ]; then
        usbserials=$(cat /sys/bus/usb/devices/*/serial)
    elif [ "$os" = "Darwin" ]; then
        usbserials=$(printf '%s' "$sp" | grep 'Serial Number' | cut -d: -f2- | sed 's/ //')
    fi

    if grep -qE '(ramdisk tool|SSHRD_Script) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [0-9]{1,2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}' <<< "$usbserials"; then
        device_mode=ramdisk
    fi
    echo "$device_mode"
}

_wait() {
    if [ "$(get_device_mode)" != "$1" ]; then
        echo "[*] Waiting for device in $1 mode"
    fi

    while [ "$(get_device_mode)" != "$1" ]; do
        sleep 1
    done

    if [ "$1" = 'recovery' ]; then
        recovery_fix_auto_boot;
    fi
}

_dfuhelper() {
    local step_one;
    deviceid=$( [ -z "$deviceid" ] && _info normal ProductType || echo $deviceid )
    if [[ "$1" = 0x801* && "$deviceid" != *"iPad"* ]]; then
        step_one="Hold volume down + side button"
    else
        step_one="Hold home + power button"
    fi
    echo "[*] To get into DFU mode, you will be guided through 2 steps:"
    echo "[*] Press any key when ready for DFU mode"
    read -n 1 -s
    step 3 "Get ready"
    step 4 "$step_one" &
    sleep 3
    "$dir"/irecovery -c "reset" &
    sleep 1
    if [[ "$1" = 0x801* && "$deviceid" != *"iPad"* ]]; then
        step 10 'Release side button, but keep holding volume down'
    else
        step 10 'Release power button, but keep holding home button'
    fi
    sleep 1

    if [ "$(get_device_mode)" = "recovery" ]; then
        _dfuhelper
    fi

    if [ "$(get_device_mode)" = "dfu" ]; then
        echo "[*] Device entered DFU!"
    else
        echo "[-] Device did not enter DFU mode, rerun the script and try again"
        return -1
    fi
}

_kill_if_running() {
    if (pgrep -u root -x "$1" &> /dev/null > /dev/null); then
        # yes, it's running as root. kill it
        sudo killall $1 &> /dev/null
    else
        if (pgrep -x "$1" &> /dev/null > /dev/null); then
            killall $1 &> /dev/null
        fi
    fi
}

ask_reboot_or_exit() {
    while true; do
        echo -n "Would you like to reboot your device or exit? (reboot/exit): "
        read -r choice

        case $choice in
            reboot)
                echo "[*] Rebooting the device..."
                remote_cmd "/usr/sbin/nvram auto-boot=true"
                remote_cmd "/sbin/reboot"
                break
                ;;
            exit)
                echo "[*] Exiting the script..."
                break;
                ;;
            *)
                echo "[!] Invalid option. Please enter 'reboot' or 'exit'."
                ;;
        esac
    done
}

_exit_handler() {
    if [ "$os" = "Darwin" ]; then
        killall -CONT AMPDevicesAgent AMPDeviceDiscoveryAgent MobileDeviceUpdater || true
    fi

    [ $? -eq 0 ] && exit
    echo "[-] An error occurred"

    if [ -d "logs" ]; then
        cd logs
        mv "$log" FAIL_${log}
        cd ..
    fi

    echo "[*] A failure log has been made. If you're going ask for help, please attach the latest log."
}
trap _exit_handler EXIT

# ===========
# Fixes
# ===========

# Prevent Finder from complaning
if [ "$os" = "Linux"  ]; then
    /bin/chmod +x getSSHOnLinux.sh
    sudo bash ./getSSHOnLinux.sh &
fi

if [ "$os" = 'Linux' ]; then
    linux_cmds='lsusb'
fi

for cmd in curl unzip python3 git ssh scp killall sudo grep pgrep ${linux_cmds}; do
    if ! command -v "${cmd}" > /dev/null; then
        echo "[-] Command '${cmd}' not installed, please install it!";
        cmd_not_found=1
    fi
done

if [ "$cmd_not_found" = "1" ]; then
    exit 1
fi

# Check for pyimg4
if ! python3 -c 'import pkgutil; exit(not pkgutil.find_loader("pyimg4"))'; then
    echo '[-] pyimg4 not installed. Press any key to install it, or press ctrl + c to cancel'
    read -n 1 -s
    python3 -m pip install pyimg4
fi

# ============disk0s1s
# Prep
# ============

# Update submodules
git submodule update --init --recursive

# Re-create work dir if it exists, else, make it
if [ -e work ]; then
    rm -rf work
    mkdir work
else
    mkdir work
fi

/bin/chmod +x "$dir"/*
#if [ "$os" = 'Darwin' ]; then
#    xattr -d com.apple.quarantine "$dir"/*
#fi

# ============
# Start
# ============

echo "dualboot | Bypass :)"
echo "Written by nizira1n "
echo ""

parse_cmdline "$@"

if [ "$debug" = "1" ]; then
    set -o xtrace
fi

if [ "$clean" = "1" ]; then
    rm -rf  work blobs/ boot/$deviceid/  ipsw/*
    echo "[*] Removed the created boot files"
    exit
fi


# Get device's iOS version from ideviceinfo if in normal mode
echo "[*] Waiting for devices"
while [ "$(get_device_mode)" = "none" ]; do
    sleep 1;
done
echo $(echo "[*] Detected $(get_device_mode) mode device" | sed 's/dfu/DFU/')

if grep -E 'pongo|checkra1n_stage2|diag' <<< "$(get_device_mode)"; then
    echo "[-] Detected device in unsupported mode '$(get_device_mode)'"
    exit 1;
fi

if [ "$(get_device_mode)" != "normal" ] && [ -z "$version" ] && [ "$dfuhelper" != "1" ]; then
    echo "[-] You must pass the version your device is on when not starting from normal mode"
    exit
fi

if [ "$(get_device_mode)" = "ramdisk" ]; then
    # If a device is in ramdisk mode, perhaps iproxy is still running?
    _kill_if_running iproxy
    echo "[*] Rebooting device in SSH Ramdisk"
    if [ "$os" = 'Linux' ]; then
        sudo "$dir"/iproxy 2222 22 >/dev/null &
    else
        "$dir"/iproxy 2222 22 >/dev/null &
    fi
    sleep 1
    remote_cmd "/sbin/reboot"
    _kill_if_running iproxy
    _wait recovery
fi

if [ "$(get_device_mode)" = "normal" ]; then
    version=${version:-$(_info normal ProductVersion)}
    arch=$(_info normal CPUArchitecture)
    if [ "$arch" = "arm64e" ]; then
        echo "[-] BYPASS doesn't, and never will, work on non-checkm8 devices"
        exit
    fi
    echo "Hello, $(_info normal ProductType) on $version!"

    echo "[*] Switching device into recovery mode..."
    "$dir"/ideviceenterrecovery $(_info normal UniqueDeviceID)
    _wait recovery
fi

# Grab more info
echo "[*] Getting device info..."
cpid=$(_info recovery CPID)
model=$(_info recovery MODEL)
deviceid=$(_info recovery PRODUCT)
ECID=$(_info recovery ECID)

echo "$cpid"
echo "$model"
echo "$deviceid"

if [ "$dfuhelper" = "1" ]; then
    echo "[*] Running DFU helper"
    _dfuhelper "$cpid"
    exit
fi

# Have the user put the device into DFU
if [ "$(get_device_mode)" != "dfu" ]; then
    recovery_fix_auto_boot;
    _dfuhelper "$cpid" || {
        echo "[-] failed to enter DFU mode, run bypassra1n.sh again"
        exit -1
    }
fi
sleep 2


# ============
# Ramdisk
# ============

# Dump blobs, and install pogo if needed 
if [ true ]; then
    mkdir -p blobs

    cd ramdisk
    /bin/chmod +x sshrd.sh
    echo "[*] Creating ramdisk"
    ./sshrd.sh $(if [[ $version == 16.* ]]; then echo "16.0.3"; else echo "15.6"; fi)

    echo "[*] Booting ramdisk"
    ./sshrd.sh boot
    cd ..
    # remove special lines from known_hosts
    if [ -f ~/.ssh/known_hosts ]; then
        if [ "$os" = "Darwin" ]; then
            sed -i.bak '/localhost/d' ~/.ssh/known_hosts
            sed -i.bak '/127\.0\.0\.1/d' ~/.ssh/known_hosts
        elif [ "$os" = "Linux" ]; then
            sed -i '/localhost/d' ~/.ssh/known_hosts
            sed -i '/127\.0\.0\.1/d' ~/.ssh/known_hosts
        fi
    fi

    # Execute the commands once the rd is booted
    if [ "$os" = 'Linux' ]; then
        sudo "$dir"/iproxy 2222 22 >/dev/null &
    else
        "$dir"/iproxy 2222 22 >/dev/null &
    fi

    if ! ("$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "echo connected" &> /dev/null); then
        echo "[*] Waiting for the ramdisk to finish booting"
    fi

    i=1
    while ! ("$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "echo connected" &> /dev/null); do
        sleep 1
        i=$((i+1))
        if [ "$i" == 15 ]; then
            if [ "$os" = 'Linux' ]; then
                echo -e "as a sudo user or your user, you should execute in another terminal:  \e[1;37mssh-keygen -f /root/.ssh/known_hosts -R \"[localhost]:2222\"\e[0m"
                read -p "Press [ENTER] to continue"
            else
                echo "mmm that looks like that ssh it's not working try to reboot your computer or send the log file trough discord"
                read -p "Press [ENTER] to continue"
            fi
        fi
    done

    echo $disk
    echo "[*] Testing for baseband presence"
    if [ "$(remote_cmd "/usr/bin/mgask HasBaseband | grep -E 'true|false'")" = "true" ] && [[ "${cpid}" == *"0x700"* ]]; then # checking if your device has baseband 
        disk=7
    elif [ "$(remote_cmd "/usr/bin/mgask HasBaseband | grep -E 'true|false'")" = "false" ]; then
        if [[ "${cpid}" == *"0x700"* ]]; then
            disk=6
        else
            disk=7
        fi
    fi

    # that is in order to know the partitions needed
    if [ "$dualboot" = "1" ]; then
        if [ "$jail_palera1n" = "1" ]; then
            disk=$(($disk + 1)) # if you have the palera1n jailbreak that will create + 1 partition for example your jailbreak is installed on disk0s1s8 that will create a new partition on disk0s1s9 so only you have to use it if you have palera1n
        fi
    fi
    echo $disk
    dataB=$(($disk + 1))
    prebootB=$(($dataB + 1))
    echo $dataB
    echo $prebootB

    if [ "$backup_activations" = "1" ] || [ "$restore_activations" = "1" ] && [ "$dualboot" = "1" ]; then
        remote_cmd "/sbin/mount_apfs /dev/disk0s1s${disk} /mnt1/"
        remote_cmd "/sbin/mount_apfs /dev/disk0s1s${dataB} /mnt2/"
    else
        remote_cmd "/usr/bin/mount_filesystems"
    fi

    
    if [ "$backup_activations" = "1" ]; then
        echo "[*] backup activations files ..."
        activationsDir=$(remote_cmd 'find /mnt2/containers/Data/System/ -type d | grep internal | sed "s|/internal.*||"')
        
        if ! remote_cmd "[ -f "$activationsDir/activation_records/activation_record.plist" ]"; then
            echo "[*] sadly we couldn't find the activation file, it could be because your device is not activated"
            ask_reboot_or_exit
            exit;
        fi

        echo "[*] activation file detected"
        echo "[*] backuping up ..."
        remote_cmd "mkdir -p /mnt1/activationsBackup/"
        remote_cmd "cp -rf $activationsDir/activation_records /mnt1/activationsBackup"
        remote_cmd "cp -rf $activationsDir/internal /mnt1/activationsBackup"
        remote_cmd "cp -rf /mnt2/mobile/Library/FairPlay /mnt1/activationsBackup"
        remote_cmd "cp -rf /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist /mnt1/activationsBackup"

        mkdir -p activationsBackup/
        mkdir -p "activationsBackup/$ECID/"
        
        remote_cp root@localhost:/mnt1/activationsBackup/ "activationsBackup/$ECID/"
        echo "[*] we saved activations files in activationsBackup/$ECID/"

        echo "[*] Rebooting the device..."
        remote_cmd "/usr/sbin/nvram auto-boot=true"
        remote_cmd "/sbin/reboot"
        exit 0;
    fi

    if [ "$restore_activations" = "1" ]; then

        if [ ! -f "activationsBackup/$ECID/activationsBackup/activation_records/activation_record.plist" ]; then
            echo "[!] it looks like you don't have activations files saved in activationsBackup/$ECID"
            ask_reboot_or_exit
            exit;
        fi

        echo "[*] restoring activations files ..."
        activationsDir=$(remote_cmd 'find /mnt2/containers/Data/System/ -type d | grep internal | sed "s|/internal.*||"')
        
        if ! remote_cmd "[ ! -f \"$activationsDir/internal\" ]"; then
            echo "[*] sadly we couldn't find the activaton directory in /mnt2/containers/Data/System/"
            ask_reboot_or_exit
            exit
        fi

        echo "[*] activation directory detected in $activationsDir"
        echo "[*] copying activations files"
        
        remote_cmd "
        if [ -d \"$activationsDir/activation_records/\" ]; then
            chflags -fR nouchg \"$activationsDir/activation_records/\";
        fi

        if [ -f \"$activationsDir/internal/data_ark.plist\" ]; then
            chflags -fR nouchg \"$activationsDir/internal/data_ark.plist\";
        fi

        if [ -f \"/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist\" ]; then
            chflags -fR nouchg \"/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist\";
        fi
        "

        remote_cmd "mkdir -p /mnt2/mobile/Media/Downloads/activationsBackup"
        remote_cp activationsBackup/"$ECID"/activationsBackup root@localhost:/mnt2/mobile/Media/Downloads/
        remote_cmd "chflags -fR nouchg /mnt2/mobile/Media/Downloads/activationsBackup"
        
        remote_cmd "/usr/sbin/chown -R mobile:mobile /mnt2/mobile/Media/Downloads/activationsBackup"

        remote_cmd "/bin/chmod -R 755 /mnt2/mobile/Media/Downloads/activationsBackup"
        remote_cmd "/bin/chmod 644 /mnt2/mobile/Media/Downloads/activationsBackup/internal/data_ark.plist /mnt2/mobile/Media/Downloads/activationsBackup/activation_records/activation_record.plist /mnt2/mobile/Media/Downloads/activationsBackup/com.apple.commcenter.device_specific_nobackup.plist"
        remote_cmd "/bin/chmod 664 /mnt2/mobile/Media/Downloads/activationsBackup/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"


        remote_cmd "cp -rf /mnt2/mobile/Media/Downloads/activationsBackup/activation_records $activationsDir/"
        remote_cmd "cp -rf /mnt2/mobile/Media/Downloads/activationsBackup/internal $activationsDir/"
        remote_cmd "cp -rf /mnt2/mobile/Media/Downloads/activationsBackup/FairPlay /mnt2/mobile/Library/"
        remote_cmd "cp -rf /mnt2/mobile/Media/Downloads/activationsBackup/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
 
        remote_cmd "/bin/chmod -R 755 /mnt2/mobile/Library/FairPlay/"
        remote_cmd "/usr/sbin/chown -R mobile:mobile /mnt2/mobile/Library/FairPlay/"
        remote_cmd "/bin/chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        
        remote_cmd "/bin/chmod -R 777 $activationsDir/activation_records/"
        remote_cmd "chflags -R uchg $activationsDir/activation_records/"

        remote_cmd "/bin/chmod 755 $activationsDir/internal/data_ark.plist"
        remote_cmd "chflags -R uchg $activationsDir/internal/data_ark.plist"

        remote_cmd "/usr/sbin/chown root:mobile /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        remote_cmd "/bin/chmod 755 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        remote_cmd "chflags uchg /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"

        echo "[*] we restored activation files from activationsBackup/$ECID/"

        echo "[*] Rebooting the device..."
        remote_cmd "/usr/sbin/nvram auto-boot=true"
        remote_cmd "/sbin/reboot"
        exit 0;
    fi

    has_active=$(remote_cmd "ls /mnt6/active" 2> /dev/null)
    if [ ! "$has_active" = "/mnt6/active" ]; then
        echo "[!] Active file does not exist! Please use SSH to create it"
        echo "    /mnt6/active should contain the name of the UUID in /mnt6"
        echo "    When done, type reboot in the SSH session, then rerun the script"
        echo "    ssh root@localhost -p 2222"
        exit
    fi
    active=$(remote_cmd "cat /mnt6/active" 2> /dev/null)

    if [ "$dualboot" = "1" ]; then
        remote_cmd "/sbin/mount_apfs /dev/disk0s1s${disk} /mnt8/"
        remote_cmd "/sbin/mount_apfs /dev/disk0s1s${dataB} /mnt9/"
        
        if [ "$back" = "1" ]; then
            remote_cmd "mv /mnt8/usr/libexec/mobileactivationdBackup /mnt8/usr/libexec/mobileactivationd "
            echo "DONE. bring BACK icloud " # that will bring back the normal icloud
            remote_cmd "/sbin/reboot"
            exit; 
        fi
        if [ $(remote_cmd "cp -av /mnt2/root/Library/Lockdown/* /mnt9/root/Library/Lockdown/.") ]; then
            echo "[*] GOT IT, COPIED THE LOCKDOWN FROM THE MAIN IOS ..."
        fi
        remote_cmd "mv /mnt8/usr/libexec/mobileactivationd /mnt8/usr/libexec/mobileactivationdBackup " # that will remplace mobileactivationd hacked
        remote_cp other/mobileactivationd root@localhost:/mnt8/usr/libexec/
        remote_cmd "ldid -e /mnt8/usr/libexec/mobileactivationdBackup > /mnt8/mob.plist"
        remote_cmd "ldid -S/mnt8/mob.plist /mnt8/usr/libexec/mobileactivationd"
        remote_cmd "rm -rv /mnt8/mob.plist"
        remote_cmd "/usr/sbin/nvram auto-boot=true"
        echo "thank you for share mobileactivationd @matty"
        echo "[*] DONE ... now reboot and boot using dualra1n"
        remote_cmd "/sbin/reboot"
        exit;
    fi

    
    if [ "$tethered" = "1" ]; then # use this if you just have tethered jailbreak
    
        if [ "$back" = "1" ]; then
            remote_cmd "mv /mnt1/usr/libexec/mobileactivationdBackup /mnt1/usr/libexec/mobileactivationd "
            echo "DONE. bring BACK icloud " # that will bring back the normal icloud
            remote_cmd "/sbin/reboot"
            exit; 
        fi
        remote_cmd "mv -i /mnt1/usr/libexec/mobileactivationd /mnt1/usr/libexec/mobileactivationdBackup " # that will remplace mobileactivationd hacked
        remote_cp other/mobileactivationd root@localhost:/mnt1/usr/libexec/
        remote_cmd "ldid -e /mnt1/usr/libexec/mobileactivationdBackup > /mnt1/mob.plist"
        remote_cmd "ldid -S/mnt1/mob.plist /mnt1/usr/libexec/mobileactivationd"
        remote_cmd "rm -rv /mnt1/mob.plist"
        remote_cmd "/usr/sbin/nvram auto-boot=false"

        echo "[*] Thank you for share the mobileactivationd @Hacktivation"
        echo "[*] Please now try to boot jailbroke in order to that the bypass work"
        echo "[*] DONE ... now reboot and boot jailbroken using palera1n or checkra1n"
        remote_cmd "/sbin/reboot"
    fi



fi

} 2>&1 | tee logs/${log}
