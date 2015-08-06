#!/bin/bash



# CONFIGURATION (STATIC VARIABLES)

# This is the full path to the avr-objdump executable
# (used in arduino IDE).
avr_path="/opt/arduino-1.6.5/hardware/tools/avr/bin/avr-objdump";

# Name of the logfile
logfile="parsing.log"

# If deleteCoreFile is set to true, the core.a file
# (from arduino) will be deleted.
deleteCoreFile=false;

# If deleteEepFile is set to true, the {projectname}.eep
# file will be deleted.
deleteEepFile=true;

# If deleteCoreFile is set to true, the different .d
# (who lists paths) will be deleted.
deleteDFiles=true;

# If deleteOFiles is set to true, the compiled .o
# files will be deleted after convertion.
deleteOElfFiles=true;

# applyDelay determines if the program should wait between
# each file, and delay is the duration in seconds. It's
# useful for debugging/checking at a human-readable speed.
applyDelay=true;
delay="1";

# If you want to see the debug infos in the terminal, set
# this to true (debug is still written into logfile).
outDebugInfo=false;



# GLOBAL VARIABLES (DYNAMIC VARIABLES)

# Used to avoid file deletion if an error has occurred
# during conversion.
ERRORLEVEL="0"; 

# Used to calculate time, for the logfile
BASETIMES="$(date +%s)";
BASETIMEN="$(date +%N)";
CURRENTS="$(($(date +%s)-BASETIME))";
CURRENTN="$(($(date +%s)-BASETIME))";



# INIT FUNCTIONS
function printInfo() {
	printf "\e[0m[\e[1;32mInfo\e[0m] ";
	echo -e "$1";

	printf "[$(date +%Y-%m-%d)][$(date +%T.%N)] ">>$logfile;
	printf "[Info] ">>$logfile;
	echo -e "$1">>$logfile;
}

function printWarn() {
	printf "\e[0m[\e[1;33mWarn\e[0m] ";
	echo -e "$1";

	printf "[$(date +%Y-%m-%d)][$(date +%T.%N)] ">>$logfile;
	printf "[Warn] ">>$logfile;
	echo -e "$1">>$logfile;
}

function printError() {
	printf "\e[0m[\e[1;31mErr.\e[0m] ";
	echo -e "$1";

	printf "[$(date +%Y-%m-%d)][$(date +%T.%N)] ">>$logfile;
	printf "[Err.] ">>$logfile;
	echo -e "$1">>$logfile;
}

function printDebug() {
	if [[ "$outDebugInfo" == true ]]; then
		printf "\e[0m[\e[1;36mDbg.\e[0m] ";
		echo -e "$1";
	fi

	printf "[$(date +%Y-%m-%d)][$(date +%T.%N)] ">>$logfile;
	printf "[Dbg.] ">>$logfile;
	echo "$1">>$logfile;
}

function checkIfFailed() {
	if [[ $? -ne 0 ]]; then
		ERROR=$(</tmp/Error);
		ERRORLEVEL="1";
		printError "$ERROR";
	else
		printInfo "\e[1;36mDone.\e[0m";
	fi
}

function removeFile() {
	if [[ $ERRORLEVEL -ne 1 ]]; then
		printInfo "Deleting $1 ...";
		rm "$1" 2> /tmp/Error;
		checkIfFailed;
	else
		printWarn "$1 can't be deleted: ERRORLEVEL flag is set to 1.";
	fi
}



# CHECKING CONFIGURATION (INIT.)

# Just here to initialise logfile 
printf "">$logfile;
printDebug "job started";

printInfo "--------------------------";
printInfo "Checking settings ....";

# Check if core.a needs to be removed, then do it.
if [[ "$deleteCoreFile" == true ]]; then
	removeFile "core.a";
	ERRORLEVEL="0";
fi
printDebug "deleteCoreFile is set to $deleteCoreFile";


# Check if {project}.eep will be deleted, and output info
if [[ "$deleteEepFile" == true ]]; then
	printWarn "File {project}.eep will be deleted.";
fi
printDebug "deleteEepFile is set to $deleteEepFile";

# Check if .d files will be deleted, and output info
if [[ "$deleteDFiles" == true ]]; then
	printWarn ".d files will be deleted.";
fi
printDebug "deleteDFiles is set to $deleteDFiles";

# Check if .o and .elf files will be deleted after
# conversion.
if [[ "$deleteOElfFiles" == true ]]; then
	printWarn "Object files (.o and .elf) will be deleted after conversion";
fi
printDebug "deleteOElfFiles is set to $deleteOElfFiles";

sleep 5;
printInfo "\e[1;36mDone.\e[0m";
printInfo "--------------------------";


# STARTING JOB : BROWSING FILES

# Main loop who browses the current directory's files.
for files in *
do
	ext="${files##*.}";
	ERRORLEVEL="0";
	
	printInfo "\e[1;34mFound\e[0m $files";

	# Convert if files are in .elf or .o format.
	if [[ "$ext" == o || "$ext" == elf ]]; then
		printInfo "--------------------------";
		
		printInfo "\e[1;34mConverting\e[0m $files (avr-objdump -S) ....";
		$avr_path -S $files>$files-S.txt 2> /tmp/Error;
		checkIfFailed;

		printInfo "\e[1;34mConverting\e[0m $files (avr-objdump -d) ....";
		$avr_path -d $files>$files-d.txt 2> /tmp/Error;
		checkIfFailed;

		printInfo "\e[1;34mConverting\e[0m $files (avr-objdump -dS) ....";
		$avr_path -dS $files>$files-dS.txt 2> /tmp/Error;
		checkIfFailed;

		if [[ "$deleteOElfFiles" == true ]]; then
			printInfo "--------------------------";
			removeFile "$files";
		else
			printWarn "$files not removed"
		fi

	# Different convertion method if file is in .hex format.
	elif [[ "$ext" == "hex" ]]; then
		printInfo "--------------------------";

		printInfo "Converting\e[0m $files (avr-objdump -j) ....";
		$avr_path -j .sec1 -d -m avr5 $files>$files-j.txt 2> /tmp/Error;
		checkIfFailed;

	# If files are {projet}.eep or in .d format, check settings
	# and remove if necessary.
	elif [[ "$ext" == "eep" && "$deleteEepFile" == true ]]; then
		removeFile "$files";
	elif [[ "$ext" == "d" && "$deleteDFiles" == true ]]; then
		removeFile "$files";

	# Otherwise, just output ignoring info.
	elif [[ "$ext" == "a" || "$ext" == "eep" || "$ext" == "d" ]]; then
		printInfo "Ignoring."
	
	# If nothing matched the previous conditions, the file
	# format isn't supported, or a directory has been found.
	else
		printWarn "$files is not supported or is a directory.";
	fi

	# Add delay between loops
	if [[ "$applyDelay" == true ]]; then
		sleep "$delay";
	fi

	printInfo "--------------------------";
done

# Info : job finished
printInfo "\e[1;36mDone.\e[0m";
printInfo "--------------------------";

# Writing end of the file into logfile
printDebug "Job ended.";
CURRENTS="$(($(date +%s)-BASETIMES))";
CURRENTN="$(($(date +%N)-BASETIMEN))";
printDebug "This file executed in $CURRENTS seconds and $CURRENTN nanoseconds";
