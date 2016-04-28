#!/bin/bash

#Función para pasar un IP a formato INT.
ip2dec () {
    local a b c d ip=$@
    IFS=. read -r a b c d <<< "$ip"
    printf '%d\n' "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

#Funcion para pasar de INT a IP

dec2ip () {
    local ip dec=$@
    for e in {3..0}
    do
        ((octet = dec / (256 ** e) ))
        ((dec -= octet * 256 ** e))
        ip+=$delim$octet
        delim=.
    done
    printf '%s\n' "$ip"
}

#Función para buscar patron
BuscarPatron() {
	local ip=$1
	local marcaTiempo=$2 
	local diferencia=$(( marcaTiempo - TablaIP[$ip,"MarcaTiempo"] ))
	local intentos=${TablaIP[$ip,"2intentosseguidos"]}
	local advertencia1=${TablaIP[$ip,"Warning1"]}
	local advertencia2=${TablaIP[$ip,"Warning2"]}
	if [[ $diferencia -le 5 ]] && [[ $intentos == 0 ]];then
		TablaIP[$ip,"2intentosseguidos"]=1 
	fi
	if [[ $diferencia -gt 1200 ]] && [[ $intentos == 1 ]] ; then
		TablaIP[$ip,"Warning1"]=1	
	fi
	if [[ $diferencia -le 5 ]] && [[ $advertencia1 == 1 ]] ; then
		TablaIP[$ip,"Warning2"]=1	
	fi
	if [[ $diferencia -gt 1200 ]] && [[ $advertencia2 == 1 ]]; then
		TablaIP[$ip,"EscaneoLento"]=1	
	fi	
}

EscribirEscaneosDetectados() {
	echo "Total escaneos detectados: ${#Escaneo[@]}"
	for IP in "${!Escaneo[@]}"; do
		IP=`dec2ip $IP`
		echo "¡¡Ups!! Perece ser que la dirección $IP nos está haciendo un escaneo lento. Para banear dicha ip utiliza:"
		echo "fail2ban-client set ssh-iptables banip $IP"
	done
}


horaactual=`date +%s`
horashaciaatras=97200 #1 semana=604800 #27 horas = 97200
ventanatemporal=$(( horaactual - horashaciaatras ))
declare -A TablaIP
declare -A Escaneo
while read ipregistro horaAcceso; do 
	horaUE=`date --date="${horaAcceso/CET/}" +%s`  #fecha en formato Unix Epoch
	if [ "$horaUE" -ge "$ventanatemporal" ]; then
		ipint=`ip2dec "$ipregistro"` #IP en formato decimal
		if [[ ${TablaIP[$ipint,"MarcaTiempo"]} ]]; then
			BuscarPatron $ipint $horaUE
			TablaIP[$ipint,"MarcaTiempo"]=$horaUE
		else 
			TablaIP[$ipint,"MarcaTiempo"]=$horaUE
			TablaIP[$ipint,"2intentosseguidos"]=0
			TablaIP[$ipint,"Warning1"]=0
			TablaIP[$ipint,"Warning2"]=0
			TablaIP[$ipint,"EscaneoLento"]=0
		fi
		if [[ ${TablaIP[$ipint,"EscaneoLento"]} == 1 ]]; then
			Escaneo[$ipint]=1
		fi
	fi
done < <(cut --only-delimited --delimiter='[' --fields=8,9 | tr --delete '[]')
EscribirEscaneosDetectados
