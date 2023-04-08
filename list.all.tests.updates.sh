#!/bin/bash

# Function to get the remaining test time or percentage for a drive
test_remaining() {
    drive=$1
    smartctl_output=$(smartctl -axc "$drive")
    if echo "$smartctl_output" | grep -q "scan progress:"; then
        test_remaining=$(echo "$smartctl_output" | grep --color % | head -1 | awk '{print $NF}')
        if [[ "$test_remaining" == "remaining" ]]; then
            test_remaining=$(echo "$smartctl_output" | grep -oE '[0-9]+%' | head -1 | awk '{print 100-$1}' | awk '{print int($1)}')%
        fi
        echo "$test_remaining"
    fi
}

# Function to get the uncorrected error values for a drive
uncorrected_errors() {
    drive=$1
    smartctl_output=$(smartctl -axc "$drive")
    read_errors=$(echo "$smartctl_output" | grep -E "read:.*" | tail -1 | sed -E 's/.* ([0-9]+)/\1/')
    write_errors=$(echo "$smartctl_output" | grep -E "write:.*" | tail -1 | sed -E 's/.* ([0-9]+)/\1/')
    verify_errors=$(echo "$smartctl_output" |grep -E "verify:.*" | tail -1 | sed -E 's/.* ([0-9]+)/\1/')
    printf "%s (r), %s (w), %s (v)\n" "$read_errors" "$write_errors" "$verify_errors"
}

# Get the list of currently running smartctl processes and extract the drives being tested
running_drives=($(ps aux | grep '[s]martctl -t long' | awk '{print $12}' | sed 's/-d sat,//g'))

# Append the running drives to the list of drives to check
drives=(
    "/dev/sdh1"
    "/dev/sdi1"
    "/dev/sdj1"
    "/dev/sdk1"
)

#drives=($(lsblk -rpo NAME,MOUNTPOINT | awk '$2!~/\/$|\/media\/cdrom/ {print ""$1}'))



# Print table header
printf "%-10s | %-20s | %-15s | %-27s | %-22s\n" "Device" "Self-Test" "% Complete" "BG Scans" "Uncorrected Errors"
printf "%-10s-+-%-20s-+-%-15s-+-%-27s-+-%-22s\n" "----------" "--------------------" "---------------" "---------------------------" "----------------------"


# Loop through each drive
for drive in "${drives[@]}"; do
    # Get the self-test progress, test remaining, background scans performed, and uncorrected errors
    smartctl_output=$(smartctl -axc "$drive")
    self_test_progress=$(echo "$smartctl_output" | perl -ne 'print "$1\n" if /# 1\s+(.*?) -\s+NOW/' | sed -e 's/Background long/BG.LONG/' -e 's/in progress/, in progress/' -e 's/^\(.\{1,20\}\).*$/\1/')
    test_remaining=$(test_remaining "$drive")
    bg_scan_results=$(echo "$smartctl_output" | perl -ne 'print "$1\n" if /Number of background scans performed: (\d+,\s+scan progress: \d+\.\d+%)/')
    uncorrected_errors=$(uncorrected_errors "$drive")

    # Print the device name, progress values, and test remaining in a table
    printf "%-10s | %-15s | %-15s | %-20s | %-22s\n" "$drive" "${self_test_progress:-Active}" "${test_remaining:-}" "${bg_scan_results:-}" "$uncorrected_errors"
done
