#!/bin/bash

servidorldap="ldaps://ldap1.hpc.cica.es:636"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="DLX39E<&q3"
ramaldap="ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"
diaactual=`date +%Y/%m/%d`
diaactualUE=`date +%s`
margenmax=`date +%s --date='-12 month'` #El tiempo de expiracion será de 1 año
declare -A Usuariosinactivos
declare -A Usuariosexpirados

informarexpiracion() {
	local nombre=$1
	local email="manuel.luna@cica.es"
	#local email=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" -s sub "uid=$nombre" mail |grep ^mail |cut -d " " -f 2`

	echo -e "Estimado usuario: \n\nNos ponemos en contacto con usted para informarle que su cuenta $nombre ha expirado en los servicios de Supercomputación de CICA. \nPuede ponerse en contacto con los servicios de supercomputación para renovar su cuenta a través de la dirección de correo eciencia@cica.es " | mail -a "Content-Type: text/plain; charset=UTF-8" -s "Expiración cuenta en los servicios de Supercomputación de CICA" -aFrom:Supercomputacion\ CICA\<eciencia@cica.es\> $email
}

informardiasrestantes() {
	local nombre=$1
	local dias=$2
	local email="manuel.luna@cica.es"
	#local email=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" -s sub "uid=$nombre" mail |grep ^mail |cut -d " " -f 2`

	echo -e "Estimado usuario: \n\nNos ponemos en contacto con usted para recordarle que su cuenta $nombre ha expirado en los servicios de Supercomputación de CICA. \nDispone de $dias días para ponerse en contacto con nosotros para que renovemos su cuenta, de lo contrario será bloqueada. \nPuede ponerse en contacto con los servicios de supercomputación a través de la dirección de correo eciencia@cica.es " | mail -a "Content-Type: text/plain; charset=UTF-8" -s "Expiración cuenta en los servicios de Supercomputación de CICA" -aFrom:Supercomputacion\ CICA\<eciencia@cica.es\> $email
}

Estadoactivo() {
	local nombre=$1
	local fecha=$2
	local fechacaducidad=`date +%Y/%m/%d -d "$fecha + 1 year"`
	local fechacaducidadUE=`date +%s -d "$fecha + 1 year"`
	local diferencia=$(((fechacaducidadUE - diaactualUE) / 86400))
	`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
add: accountStatus
accountStatus: Activo,fechacaducidad:$fechacaducidad,vida:$diferencia
EOF`	
}

Estadoexpirado() {
	local nombre=$1
	local fechaexpiracion=`date +%Y/%m/%d -d "$diaactual + 2 weeks"`
	local fechaexpiracionUE=`date +%s -d "$diaactual + 2 weeks"`
	local diferencia=$(((fechaexpiracionUE - diaactualUE) / 86400))
	local consulta=`echo ${Usuariosinactivos[$nombre]}`
	if [[ $consulta != "1" ]]; then
		`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
add: accountStatus
accountStatus: Expirado,actualizado:$diaactual,expiracion:$fechaexpiracion,vida:$diferencia
EOF`
	informarexpiracion $nombre
	fi
}

Estadoinactivo() {
	local nombre=$1
	local fechaexpiracion=`date +%Y/%m/%d -d "$diaactual + 2 weeks"`
	local fechaexpiracionUE=`date +%s -d "$diaactual + 2 weeks"`
	local diferencia=$(((fechaexpiracionUE - diaactualUE) / 86400))
	`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
add: accountStatus
accountStatus: Inactivo,actualizado:$diaactual,expiracion:$fechaexpiracion,vida:$diferencia
EOF`
	informarexpiracion $nombre
}

Actualizarestadoactivo(){
	local nombre=$1
	local estadocompleto=$2
	local fechacaducidad=`echo $estadocompleto |cut -d "," -f 2| cut -d ":" -f 2`
	local fechacaducidadUE=`date +%s -d "$fechacaducidad"`
	local diferencia=$(((fechacaducidadUE - diaactualUE) / 86400))
	echo "$nombre - accountStatus: Activo,fechacaducidad:$fechacaducidad,vida:$diferencia"
	`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: accountStatus
accountStatus: Activo,fechacaducidad:$fechacaducidad,vida:$diferencia
EOF`	

}

Actualizardiasexpirado(){
	local nombre=$1
	local expiracion=$2
	local expiracionUE=$3
	local diferencia=$(((expiracionUE - diaactualUE) / 86400))
	echo "$nombre - accountStatus: Expirado,actualizado:$diaactual,expiracion:$expiracion,vida:$diferencia"
	`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: accountStatus
accountStatus: Expirado,actualizado:$diaactual,expiracion:$expiracion,vida:$diferencia
EOF`
	if [[ $diferencia = 7 ]]; then
		informardiasrestantes $nombre $diferencia
	fi
}

Actualizardiasinactivo(){
	local nombre=$1
	local expiracion=$2
	local expiracionUE=$3
	local diferencia=$(((expiracionUE - diaactualUE) / 86400))
	echo "$nombre - accountStatus: Inactivo,actualizado:$diaactual,expiracion:$expiracion,vida:$diferencia"
	`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: accountStatus
accountStatus: Inactivo,actualizado:$diaactual,expiracion:$expiracion,vida:$diferencia
EOF`	
	if [[ $diferencia = 7 ]]; then
		informardiasrestantes $nombre $diferencia
	fi

}

Cambiaraexpirado() {
	local nombre=$1
	local fechaexpiracion=`date +%Y/%m/%d -d "$diaactual + 2 weeks"`
	local fechaexpiracionUE=`date +%s -d "$diaactual + 2 weeks"`
	local diferencia=$(((fechaexpiracionUE - diaactualUE) / 86400))
	Usuariosexpirados[$nombre]=1
	echo "Se ha cambiado a expirado $nombre - accountStatus: Expirado,actualizado:$diaactual,expiracion:$fechaexpiracion,vida:$diferencia"
	`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$nombre,$ramaldap
changeType: modify
replace: accountStatus
accountStatus: Expirado,actualizado:$diaactual,expiracion:$fechaexpiracion,vida:$diferencia
EOF`
	informarexpiracion $nombre
}

Cambiarabloqueado() {
	local nombre=$1
	echo "Se ha bloqueado a $nombre - Bloqueado,actualizado:$diaactual"
	#`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
#dn: uid=$nombre,$ramaldap
#changeType: modify
#replace: accountStatus
#accountStatus: Bloqueado,actualizado:$diaactual
#EOF`	
	
#		`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
#dn: uid=$nombre,$ramaldap
#changeType: modify
#add: pwdAccountLockedTime
#pwdAccountLockedTime: 000001010000Z
#EOF`

#		`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
#dn: uid=$nombre,$ramaldap
#changeType: modify
#replace: loginShell
#loginShell: /bin/false
#EOF`

}

Accionesestado() {
	local nombre=$1
	local estadocompleto=$2 
	local estado=`echo $estadocompleto |cut -d "," -f 1`
	if [[ $estado = "Activo" ]]; then
		local fechacaducidadactivo=`echo $estadocompleto |cut -d "," -f 2| cut -d ":" -f 2`
		local fechacaducidadactivoUE=`date +%s -d "$fechacaducidad"`
		if [[ $fechacaducidadactivoUE -lt $diaactualUE ]]; then
			Cambiaraexpirado $nombre
		else
			Actualizarestadoactivo $nombre $estadocompleto
		fi
	elif [[ $estado = "Expirado" ]]; then
		local fechaexpiracion=`echo $estadocompleto |cut -d "," -f 3| cut -d ":" -f 2`
		local fechaexpiracionUE=`date +%s -d "$fechaexpiracion"`
		if [[ $fechaexpiracionUE -lt $diaactualUE ]]; then
			Cambiarabloqueado $nombre 
		else
			Actualizardiasexpirado $nombre $fechaexpiracion $fechaexpiracionUE
		fi
	elif [[ $estado = "Inactivo" ]]; then
		local fechaexpiracioninactivo=`echo $estadocompleto |cut -d "," -f 3| cut -d ":" -f 2`
		local fechaexpiracioninactivoUE=`date +%s -d "$fechaexpiracioninactivo"`
		if [[ $fechaexpiracioninactivoUE -lt $diaactualUE ]]; then
			Cambiarabloqueado $nombre
		else
			Actualizardiasinactivo $nombre $fechaexpiracioninactivo $fechaexpiracioninactivoUE	
		fi
	fi
}


#Comprueba la última conexión de los usuarios con el script de sesamo.
Comprobarultimaconexion=`ssh sesamo "bash /opt/scripts/usuarios-ultimaConexion.sh" | egrep -v '(Nunca ha entrado|root|Nombre|accedido)' | tr -s ' ' | cut -d " " -f 1 | tail -n+4`
for usuario in $Comprobarultimaconexion; do #Comprobamos los usuarios que llevan más de 1 año sin entrar a sesamo y que no estén bloqueados.
	Estadoinactivo $usuario
	Usuariosinactivos[$usuario]=1
done



obtenerdatos=`ldapsearch -H $servidorldap  -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "createTimestamp" |egrep "^dn:|^createTimestamp:" | tr -d " " | cut -d "=" -f 2 | tr -d "\n" | sed s/Z/"\n"/g`
for i in $obtenerdatos; do
	nombre=`echo $i | cut -d "," -f 1`
	fecha=`echo $i | cut -d ":" -f 2 | cut -c 1-8`
	fechaaltaUE=`date --date="$fecha" +%s`
	estadocompleto=`ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "uid=$nombre" accountStatus | egrep ^accountStatus | cut -d " " -f 2`
	estado=`echo $estadocompleto |cut -d "," -f 1`
	if [[ $nombre != "supercomputacion" ]]; then
		if [[ $fechaaltaUE -gt $margenmax ]]; then
			if [[ $estado != "Activo" ]] && [[ $estado != "Inactivo" ]] && [[ $estado != "Expirado" ]] && [[ $estado != "Bloqueado" ]]; then
				Estadoactivo $nombre $fecha
			else
				Actualizarestadoactivo $nombre $estadocompleto
			fi
		fi
		if [[ $fechaaltaUE -lt $margenmax ]]; then
			if [[ $estado != "Activo" ]] && [[ $estado != "Inactivo" ]] && [[ $estado != "Expirado" ]] && [[ $estado != "Bloqueado" ]]; then
				Estadoexpirado $nombre
				Usuariosexpirados[$nombre]=1
			else
				Accionesestado $nombre $estadocompleto	
			fi
		fi
	fi
done


