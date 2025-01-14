#!/usr/bin/env bash

################################################################################
#                                                                              #
#    2FA-Auth // Generating '2FA' codes in your terminal                       #
#    Copyright (C) 2019  Vinicius de Alencar                                   #
#                                                                              #
#    This program is free software: you can redistribute it and/or modify      #
#    it under the terms of the GNU General Public License as published by      #
#    the Free Software Foundation, either version 3 of the License, or         #
#    (at your option) any later version.                                       #
#                                                                              #
#    This program is distributed in the hope that it will be useful,           #
#    but WITHOUT ANY WARRANTY; without even the implied warranty of            #
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             #
#    GNU General Public License for more details.                              #
#                                                                              #
#    You should have received a copy of the GNU General Public License         #
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.    #
#                                                                              #
################################################################################

source $LibraryDir/essential.sh

function TokenAdd () {
    echo "========================="
    echo "2FA-Auth // Add new token"
    echo "========================="
    echo
    echo "Service name with dots, spaces and uppercase letters are going"
    echo "to be renamed, using underlines and lowercase letter."
    echo "Example: '2FA.Auth Code' >>> '2fa_auth_code'"
    echo
    InputData "Which service do you want to include? (type 'C' to '[C]ANCEL')"

    if [[ $( echo ${Input,,} ) = "c" ]]; then
        echo "Canceling..."
    else
        Service=$( echo ${Input,,} | sed "s| \+|_|g; s|\.\+|_|g" )

        if [[ -f $TokenDir/$Service.token ]]; then
            echo "ATTENTION! '$Service' was included already!"
            echo "[TIP] Try to use an alternative name for this service."
        else
            InputData "Insert (copy/paste) 2FA token for '$Service' (type 'C' to '[C]ANCEL'):"

            if [[ $( echo ${Input,,} ) = "c" ]]; then
                echo "Canceling..."
            else
                Token="$Input"

                echo "$Token" > $TokenDir/$Service.txt && \
                $GPG -u $KeyID -r "$UserID" -o $TokenDir/$Service.token -e $TokenDir/$Service.txt && \
                    { echo "SUCCESS! '$Service' has been included using the token '$Token'" ; rm -rf $TokenDir/$Service.txt ; } || \
                    { echo "ERROR! Something wrong happened while importing the '$Service' token!" ; rm -rf $TokenDir/$Service.{token,txt} ; }
            fi
        fi
    fi
}

function TokenDel () {
    echo "========================"
    echo "2FA-Auth // Delete token"
    echo "========================"
    echo

    if [[ $( find $TokenDir -type f -name *.token | wc -l ) = "0" ]]; then
        echo "ATTENTION! No services to be excluded!"
    else
        echo "Which service do you want to exclude? (type 'A' to 'DELETE [A]LL TOKENS' or 'C' to '[C]ANCEL')"
        echo

        Array=( $( basename -a -s .token $( find $TokenDir -type f -name *.token | sort ) ) )
        Counter=

        for Number in $( seq 1 1 ${#Array[*]} ); do
            let Index=$Number-1
            echo "[$Number] ${Array[$Index]}"
            [[ $Number = ${#Array[*]} ]] && Counter=$Counter$Number || Counter=$Counter$Number"|"
        done
        Counter="+($Counter)"

        echo
        read -p "Option: " -e -n$( echo ${#Array[*]} | wc -L ) CaseOption
        CaseOption=${CaseOption,,}

        shopt -s extglob
        case $CaseOption in
            $Counter) Index=$CaseOption-1
                      Service=${Array[$Index]}
                      ConfirmAction "Are you sure you want to delete '$Service' token?" \
                                    "rm -rf $TokenDir/$Service.token" \
                                    "'$Service' token deleted!" \
                                    "It wasn't possible to delete '$Service' token!" \
                                    "Keeping '$Service' token in your profile." ;;

                   a) ConfirmAction "Are you sure you want to delete ALL tokens?" \
                                    "rm -rf $TokenDir/*.token" \
                                    "All tokens were deleted!" \
                                    "It wasn't possible to delete your tokens!" \
                                    "Keeping all tokens in your profiles." ;;

                   c) echo "Canceling..." ;;
                   *) echo "Invalid option!" ;;
        esac
        shopt -u extglob
    fi
}

function TokenCount () {
    return $( find $TokenDir -type f -name *.token | wc -l )
}
function TokenList () {
    echo "======================"
    echo "2FA-Auth // List token"
    echo "======================"
    echo

    if [[ $( TokenCount ) = "0" ]]; then
        echo "ATTENTION! Nothing to be listed!"
    else
        echo "Listing available services:"
        echo

        Array=( $( basename -a -s .token $( find $TokenDir -type f -name *.token | sort ) ) )
        Index=0

        for Number in $( seq 1 1 ${#Array[*]} ); do
            echo "[$Number] ${Array[$Index]}"
            let Index+=1
        done
    fi
}

function TokenExport () {
    function ExportToFile () {
        cat /dev/null > $HOME/$ExportFile

        ArrayService=( $( basename -a -s .token $( find $TokenDir -type f -name *.token | sort ) ) )

        Index=0
        for Service in $( basename -a -s .token $( find $TokenDir -type f -name *.token | sort ) ); do
            ArrayToken[$Index]=$( $GPG --quiet -u $KeyID -r "$UserID" -d $TokenDir/$Service.token )
            let Index+=1
        done

        Index=0
        for Number in $( seq 1 1 ${#ArrayService[*]} ); do
            echo "[$Number] $( sed -r ':loop; s| ('.'*):$|\1'.':|; t loop' <<< "$(printf '%-20s:\n' ${ArrayService[$Index]})" ) ${ArrayToken[$Index]}" \
                >> $HOME/$ExportFile
            let Index+=1
        done
    }

    echo "========================"
    echo "2FA-Auth // Export token"
    echo "========================"
    echo

    if [[ $( find $TokenDir -type f -name *.token | wc -l ) = "0" ]]; then
        echo "ATTENTION! There's no token to export!"
    else
        echo "Exporting your tokens! Please, wait..."
        echo

        if [[ -f $HOME/$ExportFile ]]; then
            echo "There's a file with exported codes!"
            Overwrite "Would you like to overwrite it?" \
                      "ExportToFile" \
                      "Your tokens were exported to $ExportFile!" \
                      "It wasn't possible to export your tokens and overwrite $ExportFile!" \
                      "Keeping your 'old' export file."
        else
            ExportToFile && echo "SUCCESS! Your tokens were exported to $ExportFile!" \
                    || echo "FAIL! It wasn't possible to export your tokens!"
        fi
    fi
}

function TokenGenerate () {
    echo "=============================="
    echo "2FA-Auth // Generate 2FA codes"
    echo "=============================="
    echo

    if [[ $( find $TokenDir -type f -name *.token | wc -l ) = "0" ]]; then
        echo "ATTENTION! No services available!"
    else
        echo "Generating 2FA codes for all available services! Please, wait..."
        echo

        search_str=$1

        ArrayService=( $( basename -a -s .token $( find $TokenDir -type f -name *.token | grep "$search_str" | sort ) ) )

        Index=0
        for Service in $( basename -a -s .token $( find $TokenDir -type f -name *.token | grep "$search_str" | sort ) ); do
            TOTP="$( $GPG --quiet --local-user $KeyID --recipient "$UserID" --decrypt $TokenDir/$Service.token 2>&1)"
            case $? in
                0) Array2FACode[$Index]="$( $OATHTOOL -b --totp "$TOTP" )" ;;
                *) Array2FACode[$Index]="n/a ($TOTP)" ;;
            esac
            let Index+=1
        done

        (
        Index=0
        for Number in $( seq 1 1 $( ls -1 $TokenDir | grep "$search_str" | wc -l ) ); do
            echo "[$Number]|${ArrayService[$Index]}:|${Array2FACode[$Index]}|[$Number]"
            let Index+=1
        done
        ) | column -t -s \|
    fi
}

function Token () {
    clear

    case $1 in
             Add) TokenAdd ;;
             Del) TokenDel ;;
            List) TokenList ;;
          Export) TokenExport ;;
        Generate) TokenGenerate $2 ;;
    esac
}
