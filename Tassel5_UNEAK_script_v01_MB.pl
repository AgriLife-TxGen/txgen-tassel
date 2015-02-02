#!/usr/bin/perl -w
use strict;
use File::Basename;
use Time::Piece;
use English qw' -no_match_vars ';

# Options ########################################
  if ($OSNAME eq "MSWin32"){
	our $TASSEL_ARGS  = "";   # In windows, the memory is defined in run_pipeline.bat, and crashes if defined again
  }
  else {
	our $TASSEL_ARGS = "-Xmx120g -Xms120g";  # In Linux/mac, the memory can be defined in the params
  }
our $FASTQ        = "0-Illumina";  
our $KEYFILE      = "0-key/Pipeline_Testing_key.txt";
our $ENZYME       = "ApeKI";
our $COMMAND      = "run_pipeline5.bat"; 
##################################################

# Base output directory on timestamp
my $date = localtime->strftime('%Y%m%d%H%M%S');

# Increment a counter for each plugin we run
our $step=0;

# Create output directories
my $dirname = dirname(__FILE__);
my $OUT = "$dirname/out.$date";
my $LogFolder = "$OUT/log";
mkdir $OUT;
mkdir $LogFolder;

sub tassel {

  my $myCommandLine;
  my @opts = @_;
  my $plugin = shift @opts;
  
  my $logfile="$OUT/log/$step-$plugin";
   
  print "\n\nRunning Step: $step - Plugin: $plugin\n\n";
  $step ++;
  
  if ($OSNAME eq "MSWin32"){
	$myCommandLine = "$COMMAND $TASSEL_ARGS -fork1 -$plugin @opts -endPlugin -runfork1";
  }
  else {
    $myCommandLine = "$COMMAND $TASSEL_ARGS -fork1 -$plugin @opts -endPlugin -runfork1 2>&1 | tee -a $logfile";
  }
  print "$myCommandLine\n\n";
  system($myCommandLine);
}

tassel(
   "FastqToTagCountPlugin",
   "-i $FASTQ",
   "-k $KEYFILE",
   "-e $ENZYME",
   "-o $OUT/tagCounts"
   );
     
tassel(
   "MergeMultipleTagCountPlugin",
   "-i $OUT/tagCounts",
   "-o $OUT/tagCount"
   );
  
tassel(
   "UTagCountToTagPairPlugin",
   "-inputFile $OUT/tagCount",
   "-outputFile $OUT/tagPairs"
   );

tassel(
   "UTagPairToTOPMPlugin",
   "-input $OUT/tagPairs",
   "-toBinary $OUT/Pairs.topm"
   );

tassel(
   "SeqToTBTHDF5Plugin",
   "-i $FASTQ",
   "-k $KEYFILE",
   "-e $ENZYME",
   "-o $OUT/TagsByTaxa.h5",
   "-L $OUT/TagsByTaxa.log",
   "-m $OUT/Pairs.topm"
   );

tassel(
   "ModifyTBTHDF5Plugin",
   "-o $OUT/TagsByTaxa.h5",
   "-p $OUT/TagsByTaxaPivot.h5"
   );

tassel(
   "DiscoverySNPCallerPlugin",
   "-i $OUT/TagsByTaxaPivot.h5",
   "-m $OUT/Pairs.topm",
   "-o $OUT/Discovery.topm",
   "-log $OUT/Discovery.topm.log",
   "-sC 1",
   "-eC 1"
   );

tassel(
   "BinaryToTextPlugin",
   "-i $OUT/Discovery.topm",
   "-o $OUT/Discovery.topm.txt",
   "-t TOPM"
   );

tassel(
   "ProductionSNPCallerPlugin",
   "-i $FASTQ",
   "-k $KEYFILE",
   "-e $ENZYME",
   "-m $OUT/Discovery.topm",
   "-o $OUT/Genotypes.h5"
   );
   
   
   