#!/bash/bin

ENDIAN=little

# Fix Endian to little_endian
export F_UFMTENDIAN=${ENDIAN}

YEAR_INI=1970
YEAR_FIN=2022

DATA_DIR="/mnt/ice09/JRA3Q/anl_p125"
TITLE="anl_p125_hgt"
VAR="HGT"
PERIOD="JJA"
DATASET="JRA3Q"

OUTDIR="${DATASET}_${YEAR_INI}_${YEAR_FIN}"
OFILE="${DATASET}_${TITLE}_${YEAR_INI}_${YEAR_FIN}_${PERIOD}.bin"
CTL_NEW="${DATASET}_${TITLE}_${YEAR_INI}_${YEAR_FIN}_${PERIOD}.ctl"


## Number of days in each month (considering leap year)
# Argument : YEAR
function DAYNUM(){
	YEAR_INPUT=$1
	if [ $(expr ${YEAR_INPUT} % 4) != 0 ]
	then
		 	#      1  2  3  4  5  6  7  8  9 10 11 12
		daynum=(0 31 28 31 30 31 30 31 31 30 31 30 31)
	elif [ $(expr ${YEAR_INPUT} % 100) = 0 -a $(expr ${YEAR_INPUT} % 400) != 0 ]
	then
			#      1  2  3  4  5  6  7  8  9 10 11 12
		daynum=(0 31 28 31 30 31 30 31 31 30 31 30 31)
	else
			#      1  2  3  4  5  6  7  8  9 10 11 12
		daynum=(0 31 29 31 30 31 30 31 31 30 31 30 31)
	fi
}	


# Make a New  Control File
# Argument : DNUM (Number of data time)
function MKCTL(){
	if [ ${DATASET} = "JRA55" ]
	then
		CTL_ORID="${DATA_DIR}/${TITLE}.ctl"
	elif [ ${DATASET} = "JRA3Q" ]
	then
		ORID_DATE=202001
		CTL_ORID="${DATA_DIR}/${ORID_DATE}/${TITLE}.${ORID_DATE}.ctl"
	else
		echo
		echo "ERROR STOP"
		echo "Invalid name of dataset"
		exit
	fi

	# Number of lines in original control file
	LINENUM=$(wc -l ${CTL_ORID} | cut -d " " -f 1)

	# Set dset statement and options statement
	DSET="dset ^${OFILE}"
	if [ ${DATASET} = "JRA55" ]
	then
		OPTION="options ${ENDIAN}_endian zrev yrev"
	elif [ ${DATASET} = "JRA3Q" ]
	then
		OPTION="options ${ENDIAN}_endian zrev"
	fi

	# Period option
	if [ ${PERIOD} = "ALL" ]
	then
		TDEF="tdef ${DNUM} linear 00Z01JAN${YEAR_INI} 6hr"
	elif [ ${PERIOD} = "MAM" ]
	then
		TDEF="tdef ${DNUM} linear 00Z01MAR${YEAR_INI} 6hr"
	elif [ ${PERIOD} = "JJA" ]
	then
		TDEF="tdef ${DNUM} linear 00Z01JUN${YEAR_INI} 6hr"
	elif [ ${PERIOD} = "SON" ]
	then
		TDEF="tdef ${DNUM} linear 00Z01SEP${YEAR_INI} 6hr"
	elif [ ${PERIOD} = "DJF" ]
	then
		TDEF="tdef ${DNUM} linear 00Z01DEC${YEAR_INI} 6hr"
	fi

	CTL_FULL="${OUTDIR}/${CTL_NEW}"

	rm -fv "${CTL_FULL}"
	# Copy lines written in the original control file if the line does not starts
	#                                   with "dset", "index", "*", "dtype", or "options"
	# If the lines starts with "dset", write correct dset statement and options statement
	while read LINE
	do
		STAT1W="$(echo "${LINE}" | cut -d " " -f 1)"

		# Get Number of Levels
		if [ "${STAT1W}" = "zdef" ]
		then
			LEVNUM="$(echo "${LINE}" | cut -d " " -f 2)"
		fi

		#echo ${STAT1W}
		if [ "${STAT1W}" = "dset" ]
		then
			#echo ${STAT1W}
			echo "${DSET}" >> "${CTL_FULL}"
			echo "${OPTION}" >> "${CTL_FULL}"
		elif [ "${STAT1W}" = "tdef" ]
		then
			echo "${TDEF}" >> "${CTL_FULL}"
		elif [ "${STAT1W}" = "vars" ]
		then
			echo -e "vars 1\n${VAR} ${LEVNUM} 99 ${VAR}\nENDVARS" >> "${CTL_FULL}"
			break
		elif [ "${STAT1W}" != "index" ] && [ "${STAT1W}" != "*" ] && [ "${STAT1W}" != "dtype" ] && [ "${STAT1W}" != "options" ]
		then
			echo "${LINE}" >> "${CTL_FULL}"
		fi
	done < "${CTL_ORID}"

}


function MESSAGE(){
	DIFF_SEC=$(expr ${END_SEC} - ${BEGIN_SEC})
	DIFF_MIN=$(expr ${DIFF_SEC} / 60)
	DIFF_SEC=$(expr ${DIFF_SEC} - ${DIFF_MIN} \* 60)
	DIFF_HR=$(expr ${DIFF_MIN} / 60)
	DIFF_MIN=$(expr ${DIFF_MIN} - ${DIFF_HR} \* 60)

	echo
	echo "COMPLETED PROCESS at ${END_DATETIME}"
	echo "PROCESSING TIME : ${DIFF_HR}hr ${DIFF_MIN}min ${DIFF_SEC}sec"
	echo
	echo "YEARS : ${YEAR_INI} - ${YEAR_FIN}"
	echo
	echo "ORIGINAL GRIB FILES : ${DATA_DIR}/YYYYMM/${TITLE}.YYYYMMDDHH"
	echo "NEW BINARY FILE : ${OUTPUT_DATA}"
	echo "VARIABLE : ${VAR}"
	echo "ENDIAN : ${ENDIAN}"
	echo
	echo "PERIOD : ${PERIOD}"
	echo
}

function MONTHLY_PROCESS(){
	YEAR_INPUT=$1
	MONTH_0=$(printf "%02d" "${MONTH}")
	DAYS_PER_MONTH=$2
	TEMPORARY="temporary_${DATASET}_${TITLE}_${PERIOD}_${YEAR_INI}_${YEAR_FIN}.bin"

	for DAY in $(seq -w 1 1 ${DAYS_PER_MONTH})
	do
		for HOUR in $(seq -w 0 6 18)
		do
			NOW=$(date "+%Y/%m/%d %H:%M:%S")

			INFILE="${DATA_DIR}/${YEAR_INPUT}${MONTH_0}/${TITLE}.${YEAR_INPUT}${MONTH_0}${DAY}${HOUR}"
			echo "${NOW} ${INFILE}" >> ${LOG}
			if [ ! -e "${INFILE}" ]
			then
				END_SEC=$(date "+%s")
				END_DATETIME=$(date "+%Y/%m/%d %H:%M:%S JST")

				MESSAGE

				MKCTL
				echo "${INFILE} does not exist" >> ${WARN}
				echo "ERROR --------------------------------------"
				echo "    ${INFILE} does not exist"
				echo "--------------------------------------------"
				exit
			fi

			if [ ${DATASET} = "JRA55" ]
			then
				wgrib ${INFILE} | grep ":${VAR}:" | wgrib ${INFILE} -i -nh -bin -o ${TEMPORARY}
			elif [ ${DATASET} = "JRA3Q" ]
			then
				wgrib2 ${INFILE} -match ":${VAR}:" -no_header -bin ${TEMPORARY}
			else
				echo
				echo "ERROR STOP"
				echo "Invalid name of dataset"
				exit
			fi
			cat ${TEMPORARY} >> ${OUTPUT_DATA}
			rm -f ${TEMPORARY}

			DNUM=$(expr ${DNUM} + 1)
		done
	done
	# echo -n "-${MONTH_0}"
}


function MONTHLY_PROCESS_DEBUG(){
	YEAR_INPUT=$1
	MONTH_0=$(printf "%02d" "${MONTH}")
	DAYS_PER_MONTH=$2
	TEMPORARY="temporary_${DATASET}_${TITLE}_${PERIOD}_${YEAR_INI}_${YEAR_FIN}.bin"

	for DAY in $(seq -w 1 1 ${DAYS_PER_MONTH})
	do
		for HOUR in $(seq -w 0 6 18)
		do
			NOW=$(date "+%Y/%m/%d %H:%M:%S")

			INFILE="${DATA_DIR}/${YEAR_INPUT}${MONTH_0}/${TITLE}.${YEAR_INPUT}${MONTH_0}${DAY}${HOUR}"
			echo "${NOW} ${INFILE}" >> ${LOG}
			if [ ! -e "${INFILE}" ]
			then
				END_SEC=$(date "+%s")
				END_DATETIME=$(date "+%Y/%m/%d %H:%M:%S JST")

				MESSAGE

				MKCTL
				echo "${INFILE} does not exist" >> ${WARN}
				echo "ERROR --------------------------------------"
				echo "    ${INFILE} does not exist"
				echo "--------------------------------------------"
				exit
			fi

			DNUM=$(expr ${DNUM} + 1)
		done
	done
	echo "${YEAR_INPUT}/${MONTH_0}"
}


function CONVERT_ALL(){

	BEGIN_SEC=$(date "+%s")

	OUTPUT_DATA="${OUTDIR}/${OFILE}"
	LOG="log_${TITLE}_${PERIOD}.txt"
	WARN="warn_${TITLE}_${PERIOD}.txt"

	rm -fv ${OUTPUT_DATA}
	rm -fv ${LOG}
	rm -fv ${WARN}
	
	DNUM=0
	for YEAR in $(seq -w ${YEAR_INI} 1 ${YEAR_FIN})
	do
		# echo -n "${TITLE}  YEAR = ${YEAR}  "
		DAYNUM ${YEAR}

		for MONTH in $(seq 1 1 12)
		do
			MONTHLY_PROCESS ${YEAR} ${daynum[MONTH]}
		done
		# echo "-  COMPLETE"
	done

	END_SEC=$(date "+%s")
	END_DATETIME=$(date "+%Y/%m/%d %H:%M:%S JST")

	MESSAGE
}


function CONVERT_MAM(){

	BEGIN_SEC=$(date "+%s")

	OUTPUT_DATA="${OUTDIR}/${OFILE}"
	LOG="log_${TITLE}_${PERIOD}.txt"
	WARN="warn_${TITLE}_${PERIOD}.txt"

	rm -fv ${OUTPUT_DATA}
	rm -fv ${LOG}
	rm -fv ${WARN}
	
	DNUM=0
	for YEAR in $(seq -w ${YEAR_INI} 1 ${YEAR_FIN})
	do
		# echo -n "${TITLE}  YEAR = ${YEAR}  "
		DAYNUM ${YEAR}

		for MONTH in $(seq 3 1 5)
		do
			MONTHLY_PROCESS ${YEAR} ${daynum[MONTH]}
		done
		# echo "-  COMPLETE"
	done

	END_SEC=$(date "+%s")
	END_DATETIME=$(date "+%Y/%m/%d %H:%M:%S JST")

	MESSAGE
}


function CONVERT_JJA(){

	BEGIN_SEC=$(date "+%s")

	OUTPUT_DATA="${OUTDIR}/${OFILE}"
	LOG="log_${TITLE}_${PERIOD}.txt"
	WARN="warn_${TITLE}_${PERIOD}.txt"

	rm -fv ${OUTPUT_DATA}
	rm -fv ${LOG}
	rm -fv ${WARN}
	
	DNUM=0
	for YEAR in $(seq -w ${YEAR_INI} 1 ${YEAR_FIN})
	do
		# echo -n "${TITLE}  YEAR = ${YEAR}  "
		DAYNUM ${YEAR}

		for MONTH in $(seq 6 1 8)
		do
			MONTHLY_PROCESS ${YEAR} ${daynum[MONTH]}
		done
		# echo "-  COMPLETE"
	done

	END_SEC=$(date "+%s")
	END_DATETIME=$(date "+%Y/%m/%d %H:%M:%S JST")

	MESSAGE
}


function CONVERT_SON(){

	BEGIN_SEC=$(date "+%s")

	OUTPUT_DATA="${OUTDIR}/${OFILE}"
	LOG="log_${TITLE}_${PERIOD}.txt"
	WARN="warn_${TITLE}_${PERIOD}.txt"

	rm -fv ${OUTPUT_DATA}
	rm -fv ${LOG}
	rm -fv ${WARN}
	
	DNUM=0
	for YEAR in $(seq -w ${YEAR_INI} 1 ${YEAR_FIN})
	do
		# echo -n "${TITLE}  YEAR = ${YEAR}  "
		DAYNUM ${YEAR}

		for MONTH in $(seq 9 1 11)
		do
			MONTHLY_PROCESS ${YEAR} ${daynum[MONTH]}
		done
		# echo "-  COMPLETE"
	done

	END_SEC=$(date "+%s")
	END_DATETIME=$(date "+%Y/%m/%d %H:%M:%S JST")

	MESSAGE
}


function CONVERT_DJF(){

	BEGIN_SEC=$(date "+%s")

	OUTPUT_DATA="${OUTDIR}/${OFILE}"
	LOG="log_${TITLE}_${PERIOD}.txt"
	WARN="warn_${TITLE}_${PERIOD}.txt"

	rm -fv ${OUTPUT_DATA}
	rm -fv ${LOG}
	rm -fv ${WARN}
	
	DNUM=0
	for YEAR in $(seq -w ${YEAR_INI} 1 $(expr ${YEAR_FIN} - 1))
	do
		# echo -n "${TITLE}  YEAR = ${YEAR}  "

		YEAR_ARG=${YEAR}
		DAYNUM ${YEAR_ARG}
		MONTH=12
		MONTHLY_PROCESS ${YEAR_ARG} ${daynum[MONTH]}
		
		YEAR_ARG=$(expr ${YEAR} + 1)
		DAYNUM ${YEAR_ARG}
		MONTH=1
		MONTHLY_PROCESS ${YEAR_ARG} ${daynum[MONTH]}
		
		YEAR_ARG=$(expr ${YEAR} + 1)
		DAYNUM ${YEAR_ARG}
		MONTH=2
		MONTHLY_PROCESS ${YEAR_ARG} ${daynum[MONTH]}
		
		# echo "-  COMPLETE"
	done

	END_SEC=$(date "+%s")
	END_DATETIME=$(date "+%Y/%m/%d %H:%M:%S JST")

	MESSAGE

}


DNUM=120000


if [ ! -d ${OUTDIR} ]
then
	mkdir ${OUTDIR}
fi

if [ "${PERIOD}" = "ALL" ]
then
	echo "CONVERTED PERIOD : ${PERIOD}"
	CONVERT_ALL
elif [ "${PERIOD}" = "MAM" ]
then
	echo "CONVERTED PERIOD : ${PERIOD}"
	CONVERT_MAM
elif [ "${PERIOD}" = "JJA" ]
then
	echo "CONVERTED PERIOD : ${PERIOD}"
	CONVERT_JJA
elif [ "${PERIOD}" = "SON" ]
then
	echo "CONVERTED PERIOD : ${PERIOD}"
	CONVERT_SON
elif [ "${PERIOD}" = "DJF" ]
then
	echo "CONVERTED PERIOD : ${PERIOD}"
	CONVERT_DJF
else
	echo
	echo "ERROR STOP"
	echo "    UNEXPECTED PERIOD"
	echo
	exit
fi

MKCTL
#echo ${TEMPORARY}

echo ${DNUM}

