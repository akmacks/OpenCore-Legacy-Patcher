/*
 * SSDT-USB-WORK.aml - Macmini5,3 USB Port Mapping for macOS Tahoe
 * Injects _UPC/_PLD methods and enables proper USB topology
 */

DefinitionBlock ("", "SSDT", 2, "OCLP", "USBWORK", 0x00001000)
{
    External (_SB.PCI0.EH01, DeviceObj)
    External (_SB.PCI0.EH02, DeviceObj)
    External (_SB.PCI0.UHC1, DeviceObj)
    External (_SB.PCI0.UHC2, DeviceObj)
    External (_SB.PCI0.UHC3, DeviceObj)
    External (_SB.PCI0.UHC4, DeviceObj)
    External (_SB.PCI0.UHC5, DeviceObj)
    External (_SB.PCI0.UHC6, DeviceObj)
    External (_SB.PCI0.UHC7, DeviceObj)

    /*
     * EH01 Root Hub (Bus 29) - 4 rear USB-A ports
     * Companion: UHC1-UHC4
     */
    Scope (_SB.PCI0.EH01)
    {
        /* Root Hub Device */
        Device (RHUB)
        {
            Name (_ADR, Zero)

            /* Port 1 - Rear USB-A */
            Device (PRT1)
            {
                Name (_ADR, One)
                Name (_UPC, Package (0x04)
                {
                    0xFF,           // Connectable
                    Zero,           // Type-A connector
                    Zero,           // Reserved
                    Zero            // Reserved
                })
                Name (_PLD, Package (0x01)
                {
                    Buffer (0x10)
                    {
                        /* Visible, rear panel, vertical orientation */
                        0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    }
                })
            }

            /* Port 2 - Rear USB-A */
            Device (PRT2)
            {
                Name (_ADR, 0x02)
                Name (_UPC, Package (0x04)
                {
                    0xFF,           // Connectable
                    Zero,           // Type-A connector
                    Zero,           // Reserved
                    Zero            // Reserved
                })
                Name (_PLD, Package (0x01)
                {
                    Buffer (0x10)
                    {
                        /* Visible, rear panel, vertical orientation */
                        0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    }
                })
            }

            /* Port 3 - Rear USB-A */
            Device (PRT3)
            {
                Name (_ADR, 0x03)
                Name (_UPC, Package (0x04)
                {
                    0xFF,           // Connectable
                    Zero,           // Type-A connector
                    Zero,           // Reserved
                    Zero            // Reserved
                })
                Name (_PLD, Package (0x01)
                {
                    Buffer (0x10)
                    {
                        /* Visible, rear panel, vertical orientation */
                        0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    }
                })
            }

            /* Port 4 - Rear USB-A */
            Device (PRT4)
            {
                Name (_ADR, 0x04)
                Name (_UPC, Package (0x04)
                {
                    0xFF,           // Connectable
                    Zero,           // Type-A connector
                    Zero,           // Reserved
                    Zero            // Reserved
                })
                Name (_PLD, Package (0x01)
                {
                    Buffer (0x10)
                    {
                        /* Visible, rear panel, vertical orientation */
                        0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    }
                })
            }
        }
    }

    /*
     * EH02 Root Hub (Bus 26) - Internal ports (Bluetooth, IR)
     * Companion: UHC5-UHC7
     */
    Scope (_SB.PCI0.EH02)
    {
        Device (RHUB)
        {
            Name (_ADR, Zero)

            /* Port 1 - Internal Hub (Bluetooth/IR) */
            Device (PRT1)
            {
                Name (_ADR, One)
                Name (_UPC, Package (0x04)
                {
                    Zero,           // Not user-visible
                    0xFF,           // Proprietary/internal
                    Zero,           // Reserved
                    Zero            // Reserved
                })
                Name (_PLD, Package (0x01)
                {
                    Buffer (0x10)
                    {
                        /* Internal, not visible */
                        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
                    }
                })
            }
        }
    }

    /*
     * UHCI Controller Properties
     * Force companion relationship with EHCI
     */
    Scope (_SB.PCI0.UHC1)
    {
        Name (_DEP, Package (0x01)
        {
            _SB.PCI0.EH01
        })
    }

    Scope (_SB.PCI0.UHC2)
    {
        Name (_DEP, Package (0x01)
        {
            _SB.PCI0.EH01
        })
    }

    Scope (_SB.PCI0.UHC3)
    {
        Name (_DEP, Package (0x01)
        {
            _SB.PCI0.EH01
        })
    }

    Scope (_SB.PCI0.UHC4)
    {
        Name (_DEP, Package (0x01)
        {
            _SB.PCI0.EH01
        })
    }

    Scope (_SB.PCI0.UHC5)
    {
        Name (_DEP, Package (0x01)
        {
            _SB.PCI0.EH02
        })
    }

    Scope (_SB.PCI0.UHC6)
    {
        Name (_DEP, Package (0x01)
        {
            _SB.PCI0.EH02
        })
    }

    Scope (_SB.PCI0.UHC7)
    {
        Name (_DEP, Package (0x01)
        {
            _SB.PCI0.EH02
        })
    }
}
