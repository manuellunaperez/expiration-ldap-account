#!/bin/bash

usuario=$1
servidorldap="ldaps://ldap1.hpc.cica.es:636"
adminldap="cn=Manager,dc=cica,dc=es"
passldap="-"
ramaldap="ou=supercomputacion,ou=externos,ou=users,ou=cuentas,dc=cica,dc=es"


ldapsearch -H $servidorldap -x -D "$adminldap" -w "$passldap" -b "uid=$usuario,$ramaldap" "modifyTimestamp" |egrep ^modifyTimestamp |cut -d " " -f 2 |cut -b 1-8

