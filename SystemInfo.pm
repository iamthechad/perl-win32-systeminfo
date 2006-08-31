package Win32::SystemInfo;

require 5.005_62;
use strict;
use warnings;
use Win32::API;
use Win32::TieRegistry;

use vars qw($VERSION);

$VERSION = '0.02';

use constant PROCESSOR_INTEL_386 => 386;
use constant PROCESSOR_INTEL_486 => 486;
use constant PROCESSOR_INTEL_PENTIUM => 586;
use constant PROCESSOR_MIPS_R4000 => 4000;
use constant PROCESSOR_ALPHA_21064 => 21064;
use constant PROCESSOR_ARCHITECTURE_INTEL => 0;
use constant PROCESSOR_ARCHITECTURE_MIPS  => 1;
use constant PROCESSOR_ARCHITECTURE_ALPHA => 2;
use constant PROCESSOR_ARCHITECTURE_PPC => 3;
use constant PROCESSOR_ARCHITECTURE_UNKNOWN => 0xFFFF;

#==================
sub MemoryStatus (\%;$) {
#==================
#
   my $return = shift;    #hash to return
   my $ret_type = shift;  #what format does the user want?
   my %fmt_types = 
   ( B => 1, KB => 1024, MB => 1024*1024, GB => 1024*1024*1024);
   my @params = qw(MemLoad TotalPhys AvailPhys TotalPage
                   AvailPage TotalVirtual AvailVirtual);
   my %results;          #results of fn call
   my $MemFormat;        #divisor for format
   my $dwMSLength;       #validator from fn call

   $MemFormat = 
   ($ret_type =~ /^[BKMG]B?$/) ? $fmt_types{$ret_type} : $fmt_types{B};

   my $GlobalMemoryStatus ||= 
   new Win32::API("kernel32", "GlobalMemoryStatus", ["P"], "V") or return;
   
   my $MEMORYSTATUS = pack "L8",(0, 0, 0, 0, 0, 0, 0, 0);

   $GlobalMemoryStatus->Call($MEMORYSTATUS);
   
   ($dwMSLength, @results{@params})  =
   unpack "L8", $MEMORYSTATUS;
   return undef if ($dwMSLength == 0);

   if (keys(%$return) == 0) {
   foreach (@params) {
    $return->{$_} = ($_ eq "MemLoad") ? $results{$_} : $results{$_}/$MemFormat;
    }
   }
   else {
    foreach (@params){
	 $return->{$_} = $results{$_}/$MemFormat unless (!defined($return->{$_}));
	 }
   }
   1;
}

#===========================
my $check_OS = sub () # Attempt to make this as private as possible
{
 my $dwPlatformId;
 my $osType;

 my $GetVersionEx ||= new Win32::API("kernel32", "GetVersionEx", ["P"], "N")
 or return undef;

 my $OSVERSIONINFO = pack "LLLLLa128",(148, 0, 0, 0, 0, "\0"x128);
 return undef if $GetVersionEx->Call($OSVERSIONINFO) == 0;
 $dwPlatformId = (unpack "LLLLLa128", $OSVERSIONINFO)[4];

 if ($dwPlatformId == 2) {  $osType ="WinNT"; }
 elsif ($dwPlatformId == 1) {  $osType = "Win9x"; }
 
 return ($osType ne "") ? $osType : undef;
};
#==========================

#==========================
sub ProcessorInfo (;\%)
{
 my $allHash = shift;
 
 # Determine operating system
 return undef unless my $OS = &$check_OS;
 
 # Make API call
 my $GetSystemInfo ||= new Win32::API("kernel32", "GetSystemInfo", ["P"], "V")
 or return undef;
 my $SYSTEM_INFO = pack("L9",0,0,0,0,0,0,0,0,0);
 $GetSystemInfo->Call($SYSTEM_INFO);

 my $proc_type; # Holds 386,586,PPC, etc
 my $num_proc;  # number of processors
 
 if ($OS eq "Win9x")
 {
  ($num_proc, $proc_type) = (unpack("L9",$SYSTEM_INFO))[5,6];
 }
 elsif ($OS eq "WinNT")
 {
  my $proc_level; # first digit of Intel chip (5,6,etc)
  my $proc_val;
  ($proc_val, $num_proc, $proc_level) 
  = (unpack("SSLLLLLLLSS",$SYSTEM_INFO))[0,6,9];
  if ($proc_val == PROCESSOR_ARCHITECTURE_INTEL) {
   $proc_type = $proc_level . "86"; }
  elsif ($proc_val == PROCESSOR_ARCHITECTURE_MIPS) {
   $proc_type = "MIPS"; }
  elsif ($proc_val == PROCESSOR_ARCHITECTURE_PPC) {
   $proc_type = "PPC"; }
  elsif ($proc_val == PROCESSOR_ARCHITECTURE_ALPHA) {
   $proc_type = "ALPHA"; }
  else { $proc_type = "UNKNOWN"; }
 }

 # if a hash was supplied, fill it with all info
 if (defined($allHash)) {
   $allHash->{NumProcessors} = $num_proc;
   $Registry->Delimiter("/");
   for (my $i = 0; $i < $num_proc; $i++) {
    my $procinfo = 
	$Registry->{"LMachine/Hardware/Description/System/CentralProcessor/$i"};
	my %prochash;
	$prochash{Identifier} = $procinfo->GetValue("Identifier");
	$prochash{VendorIdentifier} = $procinfo->GetValue("VendorIdentifier");
	if ($OS eq "WinNT") {
		$prochash{MHZ} = oct($procinfo->GetValue("~MHz"));
	} else {
		# Get speed from external DLL, since the registry value does not
		# exist in Win9x
		$prochash{MHZ} = -1;
		my $dll = $INC{'Win32/SystemInfo.pm'};
		$dll =~ s/(.*?)SystemInfo.pm/$1/i;
		$dll .= "cpuspd.dll";
		my $CpuSpeed = new Win32::API($dll, "GetCpuSpeed", ["V"], "I");
		if (!defined $CpuSpeed) {
			$allHash->{"Processor$i"} = \%prochash;
			return $proc_type;
		}
		my $aInfo = $CpuSpeed->Call();
		my $pInfo = pack("L",$aInfo);
		my $sInfo = unpack("P16",$pInfo);
		my ($in_cycles, $ex_ticks, $raw_freq, $norm_freq) =
  		unpack("L4",$sInfo);
  		$prochash{MHZ} = ($norm_freq != 0? $norm_freq:-1);
	}

	$allHash->{"Processor$i"} = \%prochash;
   }
  }
 return $proc_type;
}

1;
__END__

=head1 NAME

Win32::SystemInfo - Memory and Processor information on Win32 systems

=head1 SYNOPSIS

    use Win32::SystemInfo;

# Get Memory Information
	
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
	
# Get Processor Information

    my $proc = Win32::SystemInfo::ProcessorInfo();
	if ($proc >= 586) { ... }
	
	my %phash;
	Win32::SystemInfo::ProcessorInfo(%phash);
	for (my $i = 0; $i < $phash{NumProcessors}; $i++) {
	 print "Speed of processor $i: " . $phash{"Processor$i"}{MHZ} . "MHz\n";
	}

=head1 ABSTRACT

With this module you can get total/free memory on Win32 systems,
including installed RAM (physical memory) and page file. This module will
also let you access processor information, including processor family
(386,486,etc), speed, vendor, and revision information. 

=head1 DESCRIPTION

=over 4

Module provides two functions:

=item MemoryStatus

B<Win32::SystemInfo::MemoryStatus>(%mHash,[$format]);

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
                               - Windows 2000: The approximate percentage of
                                 total physical memory that is in use.
   TotalPhys                   - Total amount of physical memory (RAM).
   AvailPhys                   - Available physical memory (RAM).
   TotalPage                   - Allocated size of page (swap) file.
   AvailPage                   - Available page file memory.
   TotalVirtual                - Total physical + maximum page file.
   AvailableVirtual            - Total amount of available memory.
   
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

=item ProcessorInfo

$proc = B<Win32::SystemInfo::ProcessorInfo>([%pHash]);

   Determines the processor information of a Win32 computer. Returns a "quick"
   value or undef on failure. Can also populate %pHash with detailed information
   on all processors present in the system.
   
   $proc                        - Contains a numerical representation of the
                                - processor level for Intel machines. For
                                - example, a Pentium will return 586.
                                - For non-Intel Windows NT systems, the
                                - possible return values are:
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
                                - Returns -1 if unable to determine.
                                      
   PLEASE read the note about the MHz value in Caveats, below.

=back

No functions are exported. 

=head1 INSTALLATION

Installation is simple. Follow these steps:

perl makefile.pl
nmake
nmake test
nmake install

Copy the SystemInfo.html file into whatever directory you keep your
documentation in. I haven't figured out yet how to automatically copy
it over, sorry.

I've noticed that ActiveState can give an error about not being
able to find perl when processing the makefile.pl file on Win9x.
To get around this, open makefile.pl and add another key/value
pair into WriteMakefile() that looks like this:
'PERL'	=> 'full/path/to/your/perl.exe',
That should do the trick!

This module can also be used by simply placing it and the included
DLL in your /Win32 directory somewhere in @INC.

This module requires
Win32::API module by Aldo Calpini
Win32::TieRegistry by Tye McQueen

=head1 CAVEATS

The information returned by the MemoryStatus function is volatile. 
There is no guarantee that two sequential calls to this function
will return the same information. 

On computers with more than 4 GB of memory, the MemoryStatus function
can return incorrect information. Windows 2000 reports a value of -1
to indicate an overflow. Earlier versions of Windows NT report a value
that is the real amount of memory, modulo 4 GB. 

On Intel x86 computers with more than 2 GB and less than 4 GB of memory,
the MemoryStatus function will always return 2 GB for TotalPhys. 
Similarly, if the total available memory is between 2 and 4 GB, AvailPhys
will be rounded down to 2 GB.

ProcessorInfo will only reliably return CPU speed for Intel chips, and AMD
chips that support the time stamp counter. (This appears to be K6-2, K6-III,
all Athlons, and Duron.) The return value for MHz should always be checked
in a Win9x environment to verify that it is valid. (Invalid processors, or
other errors will return a -1.)

The ProcessorInfo function has been only tested in these environments:
Windows 98, Single Pentium II processor
Windows NT 4.0, Single Pentium III processor

All feedback on other configurations is greatly welcomed.  

This module has been created and tested on Windows 98 and WinNT 4.0 on
ActiveState port of Perl 5.6. It has B<not> been tested on Windows 2000 yet.

=head1 CHANGES

 0.01 - Initial Release
 0.02 - Fixed CPU speed reporting for Win9x. Module now includes a DLL that
        performs the Win9x CPU speed determination.

=head1 BUGS

Please report.

=head1 VERSION

This man page documents Win32::SystemInfo version 0.02

October 31,2000.

=head1 AUTHOR

Chad Johnston C<<>cjohnston@rockstardevelopment.comC<>>

=head1 COPYRIGHT

Copyright (C) 2000 by Chad Johnston. All rights reserved.

=head1 LICENSE

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1).

=pod SCRIPT CATEGORIES

Win32
Win32/Utilities

=cut
