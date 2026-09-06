<#
.SYNOPSIS
    Constructs the QEMU command line invocation based on the decision engine specification.
#>

function Build-QemuCommand {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Decision
    )

    $argsList = [System.Collections.Generic.List[string]]::new()

    # 1. VM Name
    $argsList.Add("-name")
    $argsList.Add("`"$($Decision.VmName)`"")

    # 2. Machine & Accelerator
    $accelOption = if ($Decision.Accelerator -eq "whpx") {
        "whpx,kernel-irqchip=off"
    } elseif ($Decision.Accelerator -eq "tcg") {
        "tcg"
    } else {
        $Decision.Accelerator
    }
    $argsList.Add("-machine")
    $argsList.Add("q35,accel=$accelOption")

    # 3. CPU model
    $argsList.Add("-cpu")
    if ($Decision.Accelerator -eq "whpx") {
        $argsList.Add("max,vmx=off")
    } elseif ($Decision.Accelerator -eq "kvm" -or $Decision.Accelerator -eq "hvf") {
        $argsList.Add("host")
    } else {
        $argsList.Add("max")
    }



    # 4. SMP (Cores)
    $argsList.Add("-smp")
    $argsList.Add("$($Decision.AllocatedCores)")

    # 5. Memory
    $argsList.Add("-m")
    $argsList.Add("$($Decision.AllocatedRamMB)")

    # 6. Primary Virtual Disk
    if ($Decision.DiskPath) {
        $argsList.Add("-drive")
        $argsList.Add("file=`"$($Decision.DiskPath)`",format=$($Decision.DiskFormat),if=virtio,cache=writeback")
    }

    # 7. UEFI / BIOS firmware
    if ($Decision.UseUefi -and $Decision.UefiFirmware) {
        $argsList.Add("-drive")
        $argsList.Add("if=pflash,format=raw,readonly=on,file=`"$($Decision.UefiFirmware)`"")
    }

    # 8. Display & Graphics
    $argsList.Add("-vga")
    $argsList.Add("virtio")

    switch ($Decision.DisplayMode.ToLower()) {
        "sdl" {
            $argsList.Add("-display")
            $argsList.Add("sdl")
        }
        "gtk" {
            $argsList.Add("-display")
            $argsList.Add("gtk")
        }
        "vnc" {
            $argsList.Add("-vnc")
            $argsList.Add("127.0.0.1:0")
        }
        default {
            $argsList.Add("-display")
            $argsList.Add("default")
        }
    }

    # 9. USB Mouse / Tablet Integration (smooth pointer without window capture trap)
    $argsList.Add("-device")
    $argsList.Add("qemu-xhci,id=xhci")
    $argsList.Add("-device")
    $argsList.Add("usb-tablet")

    # 10. Audio
    $argsList.Add("-device")
    $argsList.Add("intel-hda")
    $argsList.Add("-device")
    $argsList.Add("hda-duplex")

    # 11. Networking
    if ($Decision.NetworkMode -eq "nat") {
        $argsList.Add("-netdev")
        $argsList.Add("user,id=net0,hostfwd=tcp::$($Decision.SshPort)-:22")
        $argsList.Add("-device")
        $argsList.Add("virtio-net-pci,netdev=net0")
    }

    # 12. RTC Clock synchronization
    $argsList.Add("-rtc")
    $argsList.Add("base=utc,clock=host")

    $commandLineString = "`"$($Decision.QemuExe)`" " + ($argsList -join " ")

    return [PSCustomObject]@{
        Executable  = $Decision.QemuExe
        Arguments   = $argsList.ToArray()
        CommandLine = $commandLineString
    }
}
