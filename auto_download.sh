#!/bin/bash

#now="$(date +"%r")"
#now="$(date "+%Y%m%d%H%M")"
hour="$(date "+%H")"
echo $hour

ZERO="0"
ONE="1"
TWO="2"
THREE="3"
FOUR="4"
FIVE="5"
SIX="6"
SEVEN="7"
EIGHT="8"
NINE="9"
TEN="10"
ELEVEN="11"
TWELVE="12"
THERTEEN="13"
FOURTEEN="14"
FIFTEEN="15"
SIXTEEN="16"
SEVENTEEN="17"
EIGHTEEN="18"		
NINETEEN="19"
TWENTY="20"
TWENTYONE="21"
TWENTYTWO="22"
TWENTYTHREE="23"

download () {
		wget https://dl3.soft98.ir/win/Microsoft.Windows.10.Pro-22H2.19045.2673.x64.part1.rar?1677800518
		rm Microsoft.Windows.10.Pro-22H2.19045.2673.x64.part1.rar?1677800518
}

compare () {
   echo 'comparing ...'
   if [ $ZERO = $hour ]
   then
        echo 'Its midnight! sending to download'
        $(download)
   elif [ $ONE = $hour ]
   then
        echo 'Its 1AM! sending to download'
        $(download)
   elif [ $TWO = $hour ]
   then
        echo 'Its 2AM! sending to download'
        $(download)
   elif [ $THREE = $hour ]
   then
        echo 'Its 3AM! sending to download'
        $(download)
   elif [ $FOUR = $hour ]
   then
        echo 'Its 4AM! sending to download'
        $(download)
   elif [ $FIVE = $hour ]
   then
        echo 'Its 5AM! sending to download'
        $(download)
   elif [ $SIX = $hour ]
   then
        echo 'Its 6AM! sending to download'
        $(download)
   elif [ $SEVEN = $hour ]
   then
        echo 'Its 7AM! sending to download'
        $(download)
   elif [ $EIGHT = $hour ]
   then
        echo 'Its 8AM! sending to download'
        $(download)
   elif [ $NINE = $hour ]
   then
        echo 'Its 9AM! sending to download'
        $(download)
   elif [ $TEN = $hour ]
   then
        echo 'Its 10AM! sending to download'
        $(download)
   elif [ $ELEVEN = $hour ]
   then
        echo 'Its 11AM! sending to download'
        $(download)
   elif [ $TWELVE = $hour ]
   then
        echo 'Its 12PM! sending to download'
        $(download)
   elif [ $THERTEEN = $hour ]
   then
        echo 'Its 1PM! sending to download'
        $(download)
   elif [ $FOURTEEN = $hour ]
   then
        echo 'Its 2PM! sending to download'
        $(download)
   elif [ $FIFTEEN = $hour ]
   then
        echo 'Its 3PM! sending to download'
        $(download)
   elif [ $SIXTEEN = $hour ]
   then
        echo 'Its 4PM! sending to download'
        $(download)
   elif [ $SEVENTEEN = $hour ]
   then
        echo 'Its 5PM! sending to download'
        $(download)
   elif [ $EIGHTEEN = $hour ]
   then
        echo 'Its 6PM! sending to download'
        download     
   elif [ $NINETEEN = $hour ]
   then
        echo 'Its 7M! sending to download'
        $(download)
   elif [ $TWENTY = $hour ]
   then
        echo 'Its 8PM! sending to download'
        $(download)
   elif [ $TWENTYONE = $hour ]
   then
        echo 'Its 9PM! sending to download'
        $(download)
   elif [ $TWENTYTWO = $hour ]
   then
        echo 'Its 10PM! sending to download'
        $(download)
   elif [ $TWENTYTHREE = $hour ]
   then
        echo 'Its 11PM! sending to download'
        $(download)
   fi

}

compare
#sudo wget https://raw.githubusercontent.com/arkh91/public_script_files/main/auto_download.sh && chmod +x auto_download.sh
