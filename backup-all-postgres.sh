#!/bin/bash
#### Dependencies 
####pg_dumpall
### configurar .aws/credentials
#### s5cmd

folder=/var/lib/postgresql/13/main/backups/
cd $folder
### Se mantiene solo como respaldo, ya que no deberia de acumular backups
find $folder -type f -mtime +1 -exec rm {} \;
name=backup-postgresql13

now=`date +%m-%d-%Y-%H-%M`
check=false
COUNTER=0

function backup {
check=false
echo "comenzando dump"
if pg_dumpall -U postgres | bzip2 > $folder/$name-$now.sql.bz2  
then echo "comenzando subida" && /usr/local/bin/s5cmd --endpoint-url https://s3.us-west-000.backblazeb2.com cp $folder/$name-$now.sql.bz2 s3://coral-databases && check=true && echo "termino subida con exito"
else
    echo "Dump failed $now" >> /var/lib/postgresql/db-backup.log && check=false
fi
((COUNTER++))
echo $COUNTER
}

backup

##### acá si falla intenta 2 veces más. 
### sino falla borra el respaldo creado
if [ "$check" = true ] ; then
 echo "borrando backup local " && rm $folder/$name-$now.sql.bz2 && break
 else
	while [[ $COUNTER -lt 5 ]]
	do
  		echo $COUNTER && backup
    if [[ $COUNTER -eq 3 ]]; then
    echo "fallo el respaldo, revisar $now" >> /var/lib/postgresql/db-backup.log && break
  fi
done
fi

### backblaze has to be configured to erase erase the old files
