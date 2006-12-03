package Win32::SystemInfo;

require 5.005_62;
use strict;
use warnings;
use Win32::API 0.40;
use Win32::TieRegistry qw(:KEY_);

use vars qw($VERSION);

$VERSION = '0.09';

# Not sure how useful these are anymore -
# may get rid of them soon.
use constant PROCESSOR_ARCHITECTURE_INTEL   => 0;
use constant PROCESSOR_ARCHITECTURE_MIPS    => 1;
use constant PROCESSOR_ARCHITECTURE_ALPHA   => 2;
use constant PROCESSOR_ARCHITECTURE_PPC     => 3;
use constant PROCESSOR_ARCHITECTURE_UNKNOWN => 0xFFFF;

#===========================
my $check_OS = sub ()    # Attempt to make this as private as possible
{
	my $dwPlatformId;
	my $osType;

	# (See GetVersionEx on MSDN)
	Win32::API::Struct->typedef(
		OSVERSIONINFO => qw{
		  DWORD dwOSVersionInfoSize;
		  DWORD dwMajorVersion;
		  DWORD dwMinorVersion;
		  DWORD dwBuildNumber;
		  DWORD dwPlatformID;
		  TCHAR szCSDVersion[128];
		  }
	);

	Win32::API->Import( 'kernel32',
		'BOOL GetVersionEx(LPOSVERSIONINFO lpOSVersionInfo)' )
	  or die "Could not locate kernel32.dll - SystemInfo.pm cannot continue\n";

	my $OSVERSIONINFO = Win32::API::Struct->new('OSVERSIONINFO');
	$OSVERSIONINFO->{dwOSVersionInfoSize} =
	  148;    #Win32::API::Struct->sizeof($OSVERSIONINFO);

	GetVersionEx($OSVERSIONINFO) or return undef;
	$dwPlatformId = $OSVERSIONINFO->{dwPlatformID};
	if ( $dwPlatformId == 2 ) {
		my $majorVersion = $OSVERSIONINFO->{dwMajorVersion};
		if ( $majorVersion == 4 ) {
			$osType = "WinNT";
		}
		else {
			$osType = "Win2K";
		}
	}
	elsif ( $dwPlatformId == 1 ) { $osType = "Win9x"; }

	return ( $osType ne "" ) ? $osType : undef;
};

#==================

#==================
my $canUse64Bit = sub () { # Another private sub - see if we can do 64 bit
	eval { my $foo = pack( "Q", 1234 ) };
	return ($@) ? 0 : 1;
};

#==================

#==================
sub MemoryStatus (\%;$) {

	#==================
	#
	my $return = shift;    #hash to return
	my $ret_type ||= shift || "B";    #what format does the user want?
	my %fmt_types =
	  ( B => 1, KB => 1024, MB => 1024 * 1024, GB => 1024 * 1024 * 1024 );
	my @params = qw(MemLoad TotalPhys AvailPhys TotalPage
	  AvailPage TotalVirtual AvailVirtual);
	my %results;                      #results of fn call
	my $MemFormat;                    #divisor for format
	my $dwMSLength;                   #validator from fn call

	$MemFormat =
	  ( $ret_type =~ /^[BKMG]B?$/ ) ? $fmt_types{$ret_type} : $fmt_types{B};

	# Determine operating system
	return undef unless my $OS = &$check_OS;
	my $use64Bit = &$canUse64Bit;

	if ( ( $OS eq "Win2K" ) && ($use64Bit) ) {

		# (See GlobalMemoryStatusEx on MSDN)
		# I had to change some of the types to get the struct to
		# play nicely with Win32::API. The SIZE_T's are actually
		# DWORDS in previous versions of the Win32 API, so this
		# change doesn't hurt anything.
		# The names of the members in the struct are different than
		# in the API to make my life easier, and to keep the same
		# return values this method has always had.
		#typedef struct _MEMORYSTATUSEX {
		#	DWORD dwLength;
		#	DWORD dwMemoryLoad;
		#	DWORDLONG ullTotalPhys;
		#	DWORDLONG ullAvailPhys;
		#	DWORDLONG ullTotalPageFile;
		#	DWORDLONG ullAvailPageFile;
		#	DWORDLONG ullTotalVirtual;
		#	DWORDLONG ullAvailVirtual;
		#	DWORDLONG ullAvailExtendedVirtual;
		#}
		Win32::API::Struct->typedef(
			MEMORYSTATUSEX => qw{
			  DWORD dwLength;
			  DWORD MemLoad;
			  ULONGLONG TotalPhys;
			  ULONGLONG AvailPhys;
			  ULONGLONG TotalPage;
			  ULONGLONG AvailPage;
			  ULONGLONG TotalVirtual;
			  ULONGLONG AvailVirtual;
			  ULONGLONG AvailExtendedVirtual;
			  }
		);

		Win32::API->Import( 'kernel32',
			'BOOL GlobalMemoryStatusEx(LPMEMORYSTATUSEX lpMemoryStatusEx)' )
		  or die
		  "Could not locate kernel32.dll - SystemInfo.pm cannot continue\n";

		my $MEMORYSTATUSEX = Win32::API::Struct->new('MEMORYSTATUSEX');
		$MEMORYSTATUSEX->{dwLength} =
		  Win32::API::Struct->sizeof($MEMORYSTATUSEX);
		GlobalMemoryStatusEx($MEMORYSTATUSEX);

		if ( keys(%$return) == 0 ) {
			foreach (@params) {
				$return->{$_} =
				  ( $_ eq "MemLoad" )
				  ? $MEMORYSTATUSEX->{$_}
				  : $MEMORYSTATUSEX->{$_} / $MemFormat;
			}
		}
		else {
			foreach (@params) {
				$return->{$_} = $MEMORYSTATUSEX->{$_} / $MemFormat
				  unless ( !defined( $return->{$_} ) );
			}
		}
	}
	else {

		# (See GlobalMemoryStatus on MSDN)
		# I had to change some of the types to get the struct to
		# play nicely with Win32::API. The SIZE_T's are actually
		# DWORDS in previous versions of the Win32 API, so this
		# change doesn't hurt anything.
		# The names of the members in the struct are different than
		# in the API to make my life easier, and to keep the same
		# return values this method has always had.
		Win32::API::Struct->typedef(
			MEMORYSTATUS => qw{
			  DWORD dwLength;
			  DWORD MemLoad;
			  DWORD TotalPhys;
			  DWORD AvailPhys;
			  DWORD TotalPage;
			  DWORD AvailPage;
			  DWORD TotalVirtual;
			  DWORD AvailVirtual;
			  }
		);

		Win32::API->Import( 'kernel32',
			'VOID GlobalMemoryStatus(LPMEMORYSTATUS lpMemoryStatus)' )
		  or die
		  "Could not locate kernel32.dll - SystemInfo.pm cannot continue\n";

		my $MEMORYSTATUS = Win32::API::Struct->new('MEMORYSTATUS');
		GlobalMemoryStatus($MEMORYSTATUS);
		return undef if $MEMORYSTATUS->{dwLength} == 0;

		if ( keys(%$return) == 0 ) {
			foreach (@params) {
				$return->{$_} =
				  ( $_ eq "MemLoad" )
				  ? $MEMORYSTATUS->{$_}
				  : $MEMORYSTATUS->{$_} / $MemFormat;
			}
		}
		else {
			foreach (@params) {
				$return->{$_} = $MEMORYSTATUS->{$_} / $MemFormat
				  unless ( !defined( $return->{$_} ) );
			}
		}
	}
	1;
}

#==========================

#==========================
my $procNameLookup = sub(%$)    #another private sub
{
	my $infoHash  = shift;
	my $cpuVendor = shift;

	my $family = $infoHash->{family};
	my $model  = $infoHash->{model};

	# build a table based on vendor, otherwise a table to include
	# all entries would be a pain
	if ( $cpuVendor =~ /intel/i ) {
		my %cpuNameTable;

		$cpuNameTable{4}->{0} = "Intel 486DX";
		$cpuNameTable{4}->{1} = "Intel 486DX";
		$cpuNameTable{4}->{2} = "Intel 486SX";
		$cpuNameTable{4}->{3} = "Intel 487, DX2, or DX2 Overdrive";
		$cpuNameTable{4}->{4} = "Intel 486 SL";
		$cpuNameTable{4}->{5} = "Intel SX2";
		$cpuNameTable{4}->{7} = "Intel Write-Back Enhanced DX2";
		$cpuNameTable{4}->{8} = "Intel DX4 or DX4 Overdrive";
		$cpuNameTable{5}->{1} = "Intel Pentium or Pentium Overdrive";
		$cpuNameTable{5}->{2} = "Intel Pentium or Pentium Overdrive";
		$cpuNameTable{5}->{3} = "Intel Pentium Overdrive for 486 systems";
		$cpuNameTable{5}->{4} = "Intel Pentium or Pentium Overdrive with MMX";
		$cpuNameTable{6}->{1} = "Intel Pentium Pro";
		$cpuNameTable{6}->{3} = "Intel Pentium II";
		$cpuNameTable{6}->{5} = "Intel Pentium II, Pentium II Xeon, or Celeron";
		$cpuNameTable{6}->{6} = "Intel Celeron";
		$cpuNameTable{6}->{7} = "Intel Pentium III or Pentium III Xeon";
		$cpuNameTable{6}->{8} =
		  "Intel Pentium III, Pentium III Xeon, or Celeron";
		$cpuNameTable{6}->{10} = "Intel Pentium III Xeon";
		$cpuNameTable{6}->{3}  = "Intel Pentium II Overdrive";
		$cpuNameTable{16}->{0} = "Intel Pentium 4 or Xeon";
		$cpuNameTable{16}->{1} = "Intel Pentium 4, Xeon, Xeon MP, or Celeron";
		$cpuNameTable{16}->{2} =
"Intel Pentium 4, Mobile Pentium 4, Xeon, Mobile Xeon, Celeron, or Mobile Celeron";

		return ( exists( $cpuNameTable{$family}->{$model} ) )
		  ? $cpuNameTable{$family}->{$model}
		  : "Unknown";
	}
	elsif ( $cpuVendor =~ /AMD/i ) {
		my %cpuNameTable;

		$cpuNameTable{5}->{0} = "AMD-K5 Model 0";
		$cpuNameTable{5}->{1} = "AMD-K5 Model 1";
		$cpuNameTable{5}->{2} = "AMD-K5 Model 2";
		$cpuNameTable{5}->{3} = "AMD-K5 Model 3";
		$cpuNameTable{5}->{6} = "AMD-K6 Model 6";
		$cpuNameTable{5}->{7} = "AMD-K6 Model 7";
		$cpuNameTable{5}->{8} = "AMD-K6-2 Model 8";
		$cpuNameTable{5}->{9} = "AMD-K6 III Model 9";
		$cpuNameTable{6}->{1} = "AMD Athlon Model 1";
		$cpuNameTable{6}->{2} = "AMD Athlon Model 2";
		$cpuNameTable{6}->{3} = "AMD Duron Model 3";
		$cpuNameTable{6}->{4} = "AMD Athlon Model 4";
		$cpuNameTable{6}->{6} =
"AMD Athlon MP, Athlon XP, Mobile Athlon 4, Duron, or Mobile Duron Model 6";
		$cpuNameTable{6}->{7}  = "AMD Duron or Mobile Duron Model 7";
		$cpuNameTable{6}->{8}  = "AMD Athlon XP or Athlon MP Model 8";
		$cpuNameTable{6}->{10} =
"AMD Mobile Athlon XP-M, Mobile Athlon XP-M (LV) Model 8, or Athlon XP, Athlon MP, Mobile Athlon XP-M Model 10";

		# the model numbering on these is a bit odd, but we're
		# in the ballpark with this answer
		if ( $family == 4 ) {
			return "Am486 or Am5x86";
		}

		return ( exists( $cpuNameTable{$family}->{$model} ) )
		  ? $cpuNameTable{$family}->{$model}
		  : "Unknown";
	}

	return "Unknown";
};

#==========================

#==========================
sub ProcessorInfo (;\%) {
	my $allHash = shift;

	# Determine operating system
	return undef unless my $OS = &$check_OS;

	# (See GetSystemInfo on MSDN)
	# Win32::API does not seem to recognize LPVOID or DWORD_PTR types,
	# so they've been changed to DWORDs in the struct. These values are
	# not checked by this module, so this seems like a safe way around the
	# problem.
	Win32::API::Struct->typedef(
		SYSTEM_INFO => qw{
		  WORD wProcessorArchitecture;
		  WORD wReserved;
		  DWORD dwPageSize;
		  DWORD lpMinimumApplicationAddress;
		  DWORD lpMaximumApplicationAddress;
		  DWORD dwActiveProcessorMask;
		  DWORD dwNumberOfProcessors;
		  DWORD dwProcessorType;
		  DWORD dwAllocationGranularity;
		  WORD wProcessorLevel;
		  WORD wProcessorRevision;
		  }
	);

	Win32::API->Import( 'kernel32',
		'VOID GetSystemInfo(LPSYSTEM_INFO lpSystemInfo)' )
	  or die "Could not locate kernel32.dll - SystemInfo.pm cannot continue\n";
	my $SYSTEM_INFO = Win32::API::Struct->new('SYSTEM_INFO');
	GetSystemInfo($SYSTEM_INFO);

	my $proc_type;    # Holds 386,586,PPC, etc
	my $num_proc;     # number of processors

	$num_proc = $SYSTEM_INFO->{dwNumberOfProcessors};
	if ( $OS eq "Win9x" ) {
		$proc_type = $SYSTEM_INFO->{dwProcessorType};
	}
	elsif ( ( $OS eq "WinNT" ) || ( $OS eq "Win2K" ) ) {
		my $proc_level;    # first digit of Intel chip (5,6,etc)
		my $proc_val;
		$proc_val   = $SYSTEM_INFO->{wProcessorArchitecture};
		$proc_level = $SYSTEM_INFO->{wProcessorLevel};

		# Not sure we need to make this check - who
		# uses this value?
		if ( $proc_val == PROCESSOR_ARCHITECTURE_INTEL ) {
			$proc_type = $proc_level . "86";
		}
		elsif ( $proc_val == PROCESSOR_ARCHITECTURE_MIPS ) {
			$proc_type = "MIPS";
		}
		elsif ( $proc_val == PROCESSOR_ARCHITECTURE_PPC ) {
			$proc_type = "PPC";
		}
		elsif ( $proc_val == PROCESSOR_ARCHITECTURE_ALPHA ) {
			$proc_type = "ALPHA";
		}
		else { $proc_type = "UNKNOWN"; }
	}

	# if a hash was supplied, fill it with all info
	if ( defined($allHash) ) {
		$allHash->{NumProcessors} = $num_proc;
		$Registry->Delimiter("/");
		for ( my $i = 0 ; $i < $num_proc ; $i++ ) {
			my $procinfo =
			  $Registry->Open(
				"LMachine/Hardware/Description/System/CentralProcessor/$i",
				{ Access => KEY_READ() } );
			my %prochash;
			$prochash{Identifier}       = $procinfo->GetValue("Identifier");
			$prochash{VendorIdentifier} =
			  $procinfo->GetValue("VendorIdentifier");
			$prochash{MHZ} = hex $procinfo->GetValue("~MHz");

#$prochash{ProcessorName} = &$procNameLookup(\%pNameHash,$prochash{VendorIdentifier});
			$prochash{ProcessorName} =
			  $procinfo->GetValue("ProcessorNameString");
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
(386,486,etc), speed, name, vendor, and revision information.

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
   ProcessorName                - The name of the processor, such as
                                - "Intel Pentium", or "AMD Athlon".

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
<br>Win32::API module by Aldo Calpini


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

The ProcessorName value returned by ProcessorInfo may sometimes
reference more than one processor. For example, the returned value
may be "Intel Pentium or Pentium Overdrive". There are ways to tell
these processors apart programmatically, but I did not take the time
to implement the extra code in this release.

The ProcessorInfo function has been only tested in these environments:
Windows 98, Single Pentium II processor
Windows NT 4.0, Single Pentium III processor
Windows XP Pro, Single Athlon processor

All feedback on other configurations is greatly welcomed.

This module has been created and tested on Windows 98 and WinNT 4.0 on
ActiveState port of Perl 5.6. It has B<not> been extensively
tested on Windows 2000 yet.

=head1 CHANGES

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

=head1 BUGS

Please report.

=head1 VERSION

This man page documents Win32::SystemInfo version 0.09

November 23, 2006.

=head1 AUTHOR

Chad Johnston C<<>cjohnston@megatome.comC<>>

=head1 COPYRIGHT

Copyright (C) 2006 by Chad Johnston. All rights reserved.

=head1 LICENSE

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

perl(1).

=pod SCRIPT CATEGORIES

Win32
Win32/Utilities

=cut
