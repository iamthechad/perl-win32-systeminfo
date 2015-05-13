[![CPAN version](https://badge.fury.io/pl/Win32-SystemInfo.svg)](http://badge.fury.io/pl/Win32-SystemInfo)

# NAME

Win32::SystemInfo - Memory and Processor information on Win32 systems

# SYNOPSIS

    use Win32::SystemInfo;

\# Get Memory Information

    my %mHash;
    if (Win32::SystemInfo::MemoryStatus(%mHash))
    {
     ...process results...
    }

    To get specific values:
    my %mHash = (TotalPhys => 0, AvailPhys => 0);
    if (Win32::SystemInfo::MemoryStatus(%mHash))
    {
     ...mHash contains only TotalPhys and AvailPhys values...
    }

    Change the default return value:
    Win32::SystemInfo::MemoryStatus(%mHash,"MB");

\# Get Processor Information

    # This usage is considered deprecated
    my $proc = Win32::SystemInfo::ProcessorInfo();

    my %phash;
    Win32::SystemInfo::ProcessorInfo(%phash);
    for (my $i = 0; $i < $phash{NumProcessors}; $i++) {
     print "Speed of processor $i: " . $phash{"Processor$i"}{MHZ} . "MHz\n";
    }

# ABSTRACT

With this module you can get total/free memory on Win32 systems,
including installed RAM (physical memory) and page file. This module will
also let you access processor information, including processor family
(386,486,etc), speed, name, vendor, and revision information.

# DESCRIPTION

- __MemoryStatus__

    __Win32::SystemInfo::MemoryStatus__(%mHash,\[$format\]);

        %mHash                      - The hash that will receive the results.
                                      Certain values can be set prior to the
                                      call to retrieve a subset. (See below)
        $format                     - Optional parameter. Used to set the order
                                      of magnitude of the results. (See below)

        Determines the current memory status of a Win32 machine. Populates
        %mHash with the results. Function returns undef on failure.

        Values returned through the hash:
        MemLoad                     - Windows NT 3.1 to 4.0: The percentage of
                                      approximately the last 1000 pages of physical
                                      memory that is in use.
                                    - Windows 2000 and later: The approximate percentage of
                                      total physical memory that is in use.
        TotalPhys                   - Total amount of physical memory (RAM).
                                    - For Windows 2k and earlier, see CAVEATS below about 
                                    - the accuracy of this value.
        AvailPhys                   - Available physical memory (RAM).
        TotalPage                   - Allocated size of page (swap) file.
        AvailPage                   - Available page file memory.
        TotalVirtual                - Total physical + maximum page file.
        AvailVirtual                 - Total amount of available memory.

        Values returned through the hash can also be specified by setting
        them before the function is called.
            my %mHash = (TotalPhys => 0);
            Win32::MemoryInfo::MemoryStatus(%mHash);

        Will return only the total physical memory.

        MemoryStatus return values in bytes by default. This can be changed with
        the $format parameter. Valid values for $format are:
            B        -  Bytes (default)
            KB       -  Kilobytes
            MB       -  Megabytes
            GB       -  Gigabytes

- __ProcessorInfo__

    $proc = __Win32::SystemInfo::ProcessorInfo__(\[%pHash\]);

        Determines the processor information of a Win32 computer. Returns a "quick"
        value or undef on failure. Can also populate %pHash with detailed information
        on all processors present in the system.

        $proc                        - THIS VALUE HAS BEEN MADE OBSOLETE
                                     - FOR WINDOWS NT AND LATER. RELY ON IT
                                     - AT YOUR OWN RISK.
                                     - Contains a numerical representation of the
                                     - processor level for Intel machines. For
                                     - example, a Pentium will return 586.
                                     - For non-Intel Windows NT systems, the
                                     - possible return values are:
                                     - x64: AMD64
                                     - PPC: PowerPC
                                     - MIPS: MIPS architecture
                                     - ALPHA: Alpha architecture
                                     - UNKNOWN: Unknown architecture

        %pHash                       - Optional parameter. Will be filled with
                                     - information about all processors.

        Values returned through hash:
        NumProcessors                - The number of processors installed
        ProcessorN                   - A hash containing all info for processor N

        Each ProcessorN hash contains the values:
        Identifier                   - The identifier string for the processor
                                     - as found in the registry. The computer I'm
                                     - currently using returns the string
                                     - "x86 Family 6 Model 7 Stepping 3"
        VendorIdentifier             - The vendor name of the processor
        MHZ                          - The speed in MHz of the processor
                                     - This is not a calculated value, but the value
                                     - that is recorded in the Windows registry.
                                     - This value will be -1 for pre Windows NT
                                     - systems (95/98/Me). 
        ProcessorName                - The name of the processor, such as
                                     - "Intel Pentium", or "AMD Athlon".

        PLEASE read the note about the MHz value in Caveats, below.

No functions are exported.

# INSTALLATION

Installation is simple. Follow these steps:

    perl Makefile.PL
    nmake
    nmake test
    nmake install

Copy the SystemInfo.html file into whatever directory you keep your
documentation in. I haven't figured out yet how to automatically copy
it over, sorry.

Nmake can be downloaded from [http://download.microsoft.com/download/vc15/Patch/1.52/W95/EN-US/Nmake15.exe](http://download.microsoft.com/download/vc15/Patch/1.52/W95/EN-US/Nmake15.exe)
Alternatively, Strawberry Perl includes dmake that can be used instead.

This module can also be used by simply placing it /Win32 directory 
somewhere in @INC.

This module requires

Win32::API by Aldo Calpini

Win32::TieRegistry by Tye McQueen

# CAVEATS

The information returned by the MemoryStatus function is volatile.
There is no guarantee that two sequential calls to this function
will return the same information.

On 32 bit computers with more than 4 GB of memory, the MemoryStatus function
can return incorrect information. Windows 2000 reports a value of -1
to indicate an overflow. Earlier versions of Windows NT report a value
that is the real amount of memory, modulo 4 GB.

On 32 bit Intel x86 computers with more than 2 GB and less than 4 GB of memory,
the MemoryStatus function will always return 2 GB for TotalPhys.
Similarly, if the total available memory is between 2 and 4 GB, AvailPhys
will be rounded down to 2 GB.

64 bit systems using 64 bit versions of Perl will report the correct amount of 
physical memory.

ProcessorInfo will only return the CPU speed that is reported in the Windows
registry. This module used to include a DLL that performed a CPU speed calculation,
but all of these new-fangled processors caused the code to break. I don't have the
time or energy to rewrite the module so that it will play well with Dual Core,
Hyperthreading, and what else. The value from the registry appears to be accurate
on the machines I've tested this module on. Windows 9x/Me will return values of -1
for processor speed, as their registries don't store the MHz value. If you're using
Win9x/Me and need the MHz value, use an older version of this module. Sorry.

The ProcessorName value is also pulled straight from the registry. Correctly
determining the processor's name requires throwing some assembly at it, and 
if you've read the previous paragraph you'll know that DLL that threw assembly
at the processor has been removed from this module.

All feedback on other configurations is greatly welcomed.

# CHANGES

    0.01 - Initial Release
    0.02 - Fixed CPU speed reporting for Win9x. Module now includes a DLL that
           performs the Win9x CPU speed determination.
    0.03 - Fixed warning "use of uninitialized value" when calling MemoryStatus
           with no size argument.
    0.04 - Fixed "GetValue" error when calling ProcessorInfo as non-admin user
           on WindowsNT
           - Fixed documentation bug: "AvailableVirtual" to "AvailVirtual"
    0.05 - Fixed bug introduced in 0.03 where $format was ignored in
           MemoryStatus. All results were returned in bytes regardless of
           $format parameter.
    0.06 - Added new entry to processor information hash to display the name
           of the processor. WindowsNT and 2K now use the DLL to determine
           CPU speed as well.
    0.07 - Changed contact information. Recompiled DLL to remove some extraneous calls.
    0.08 - Added more definitions for recent CPUs. Added dependency on version 0.40
           of Win32::API. Reworked Win32::API calls. Changed calls in DLL to
           eliminate need to pack and unpack arguments.
    0.09 - Eliminated cpuspd.dll. Should eliminate some of the headaches associated with
           using this module. It should now return CPU info for all flavors of 
           Windows past Win9x without crashing.
    0.10 - Added bug description for Perl Development Kit. Fixed link to ActiveState module
           location.
    0.11 - Suppress warnings that come from Win32::API when running with the -w switch. Fix bug
           (http://rt.cpan.org/Public/Bug/Display.html?id=30894) where memory could grow 
           uncontrollably.
    0.12 - Fix some 64 bit related bugs. Use correct SYSTEM_INFO structure 
           (http://rt.cpan.org/Public/Bug/Display.html?id=59365) and use correct struct size
           (http://rt.cpan.org/Public/Bug/Display.html?id=48008).

# BUGS

For versions 0.09 and forward, there is a compatibility bug with ActiveState's Perl Development
Kit version 6. Apparently the PDK has been designed to expect the cpuspd.dll file to be present and
fails against versions of this module that do not include the DLL anymore. For details on the bug
and workaround instructions, see this URL: [http://bugs.activestate.com/show\_bug.cgi?id=67333](http://bugs.activestate.com/show\_bug.cgi?id=67333)

# VERSION

This man page documents Win32::SystemInfo version 0.12

February 17, 2013.

# AUTHOR

Chad Johnston `<`cjohnston@megatome.com``\>

# COPYRIGHT

Copyright (C) 2013 by Chad Johnston. All rights reserved.

# LICENSE

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# SEE ALSO

perl(1).

Win32
Win32/Utilities
