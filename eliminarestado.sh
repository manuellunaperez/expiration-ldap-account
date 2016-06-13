#!/bin/bash

servidorldap="ldaps://ldap1.hpc.cica.es:636"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="DLX39E<&q3"
ramaldap="ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"

obtenerestado=`ldapsearch -H $servidorldap  -x -D "$adminldap" -w "$passldap" -b "$ramaldap" "uid" | egrep ^uid | tr -d " " | cut -d ":" -f 2`
for i in $obtenerestado; do
	if [[ $i != "supercomputacion" ]]; then
	`2>/dev/null 1>/dev/null ldapadd -H $servidorldap -x -D "$adminldap" -w "$passldap" << EOF                                                                                  
dn: uid=$i,$ramaldap
changeType: modify
delete: accountStatus
EOF`
	fi
done
