#!/bin/bash


function getStockInfo {
    local DIVIDEND1=0
    DIVIDEND=7
    PRICE=`wget -q  https://www.nzx.com/instruments/$1 -O - | hxnormalize   -x -e 2> /dev/null | hxselect  -c 'div.medium-5 h1' | sed 's/ \|\\$//g'`
    local  POS=0
    while read line; do
	case $POS in
	    0)
	        ;;
	    1)

	    YMD=`echo $line | sed 's/^.*"\(.*\)".*$/\1/g'`
		DIVDATE=`date -d $YMD +%s`
		;;

	    2)
		;;
	    3)
		DIVAMT=`echo $line | sed -e "s/[^0-9.]//g"`
		;;
	    4)
   		SUPAMT=`echo $line | sed -e "s/[^0-9.]//g"`
		;;
		5)
		IMPAMT=`echo $line | sed -e "s/[^0-9.]//g"`
        ;;
	    6)
   	    YMD=`echo $line | sed 's/^.*"\(.*\)".*$/\1/g'`

		DIVPAYDATE=`date -d $YMD +%s`
		
		if (( $DIVDATE >= $2 )); then
		    DIVIDEND1=`echo "$DIVIDEND1 + ($DIVAMT + $SUPAMT - $IMPAMT) / 100" | bc -l`
		fi
		;;
	esac
	POS=`expr \( $POS + 1 \) % 8`
    done < <(wget -q https://www.nzx.com/instruments/$1/dividends -O - |  hxnormalize -x -l 10000 | hxselect -c -s '\n' 'td' )
    DIVIDEND=$DIVIDEND1

}

#cat AIR | 

#printf "STOCK\t\t%1sQTY\t%5sCUR PRICE\t%3sANL CHANGE\t%3sCUR VAL\t%3sABS CHANGE\t%5sDIVIDEND RET\tAMT INVESTED\n"
printf "STOCK\t%8sQTY\tPUR PRICE($)\t%2sCUR PRICE($)\tAMT INVESTED($)\t%3sCUR VAL($)\t%2sCHANGE($)\tABS CHANGE(%%)\tDIVIDEND RET(%%)\t%2sANL CHANGE(%%)\n"


TOTPVAL=0
TOTWVAL=0
TOTCURVAL=0
TOTINVVAL=0
TOTCHANGE=0
while read line; do
    line=`echo $line|tr -d '[:space:]'`
    if [ "$line" == "" ] ; then
	continue
    fi
    STOCK=`echo $line | awk -F , '{print $1}'`
    DATE=`echo $line | awk -F , '{print $2}'`
    AMOUNT=`echo $line | awk -F , '{print $3}'`
    PURCHASE=`echo $line | awk -F , '{print $4}'`
    
    D=`echo $DATE | awk -F / '{print $1}'`
    M=`echo $DATE | awk -F / '{print $2}'`
    Y=`echo $DATE | awk -F / '{print $3}'`
    NOW=`date +%s`
    THEN=`date -d 20$Y-$M-$D +%s`
    OWNED=`expr \( $NOW - $THEN \) / 86400`
    YEARSOWNED=`echo $OWNED / 365.0 | bc -l `
    getStockInfo $STOCK $THEN
    CURVAL=`echo $AMOUNT \* $PRICE | bc -l`
    TOTCURVAL=`echo $CURVAL + $TOTCURVAL | bc -l`
    ANUALGAIN=`echo "e(l( $PRICE/$PURCHASE )/ $YEARSOWNED ) - 1" | bc -l`
    GAINP=`echo "(($PRICE/$PURCHASE) - 1) * 100 " | bc -l`
    AMTINVEST=`echo $AMOUNT \* $PURCHASE | bc -l`
    TOTINVVAL=`echo $AMTINVEST + $TOTINVVAL | bc -l`
    CHANGEVAL=`echo $CURVAL - $AMTINVEST | bc -l`
    TOTCHANGE=`echo $CHANGEVAL + $TOTCHANGE | bc -l`
    # the maxiumn loss shares can have is 100%
    ANUALGAIN=`echo "if ($ANUALGAIN < -1) -1 else $ANUALGAIN" | bc -l`
    PURCHASEVAL=`echo $PURCHASE \* $AMOUNT | bc -l`
    DIVP=`echo "($DIVIDEND / $PURCHASE) * 100  " | bc -l` 
    WGAIN=`echo $PURCHASEVAL \* $ANUALGAIN | bc -l` 
    TOTWVAL=`echo $TOTWVAL + $WGAIN | bc -l`
    TOTPVAL=`echo $TOTPVAL + $PURCHASEVAL | bc -l`
    ANULGAINP=`echo $ANUALGAIN \* 100 | bc -l`
    printf "%s\t%11s\t%10s\t%10s\t%10.2f\t%'12.2f\t%'10.2f\t%10.2f\t%8.2f\t%10.2f\n" $STOCK $AMOUNT $PURCHASE $PRICE $AMTINVEST $CURVAL $CHANGEVAL $GAINP $DIVP $ANULGAINP

done < $1

GAIN=`echo $TOTWVAL / $TOTPVAL \* 100 | bc -l`
#printf "Total\t\t\t\t\t%10.2f%% \t$%'10.2f\t\t\t\t\t\t$%'10.2f\n" $GAIN $TOTCURVAL $TOTINVVAL
printf "Total\t\t\t\t\t\t\t%'10.2f\t%'12.2f\t%10.2f\t\t\t\t\t%10.2f\n"  $TOTINVVAL $TOTCURVAL $TOTCHANGE $GAIN
