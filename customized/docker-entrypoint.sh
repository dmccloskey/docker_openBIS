#!/bin/bash
set -e

if [ -d "/home/openbis/openbis_state/postgresql_data" ]; then
	echo "Using existing openbis_state"
else
	echo "Creating new openbis_state"
	unzip -o /home/openbis/openbis_state_template.zip -d /home/openbis
	chown -R openbis /home/openbis/openbis_state
	chown -R postgres /home/openbis/openbis_state/postgresql_data
	rm -rf /home/openbis/openbis/servers/openBIS-server/jetty/logs
	ln -s /home/openbis/openbis_state/as_logs /home/openbis/openbis/servers/openBIS-server/jetty/logs
	rm -rf /home/openbis/store
	ln -s /home/openbis/openbis_state/dss_store /home/openbis/store
	rm -rf /home/openbis/openbis/servers/datastore_server/data/sessionWorkspace
	ln -s /home/openbis/openbis_state/dss_session_workspace /home/openbis/openbis/servers/datastore_server/data/sessionWorkspace
	rm -rf /home/openbis/openbis/servers/datastore_server/log
	ln -s /home/openbis/openbis_state/dss_logs /home/openbis/openbis/servers/datastore_server/log
fi

export PGDATA=/home/openbis/openbis_state/postgresql_data

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

if [ "${1:0:1}" = '-' ]; then
	set -- postgres "$@"
fi

if [ "$1" = 'postgres' ]; then
	mkdir -p "$PGDATA"
	chmod 700 "$PGDATA"
	chown -R postgres "$PGDATA"

	mkdir -p /run/postgresql
	chmod g+s /run/postgresql
	chown -R postgres /run/postgresql

	# look specifically for PG_VERSION, as it is expected in the DB dir
	if [ ! -s "$PGDATA/PG_VERSION" ]; then
		file_env 'POSTGRES_INITDB_ARGS'
		eval "gosu postgres initdb $POSTGRES_INITDB_ARGS"

		# check password first so we can output the warning before postgres
		# messes it up
		file_env 'POSTGRES_PASSWORD'
		if [ "$POSTGRES_PASSWORD" ]; then
			pass="PASSWORD '$POSTGRES_PASSWORD'"
			authMethod=md5
		else
			# The - option suppresses leading tabs but *not* spaces. :)
			cat >&2 <<-'EOWARN'
				****************************************************
				WARNING: No password has been set for the database.
				         This will allow anyone with access to the
				         Postgres port to access your database. In
				         Docker's default configuration, this is
				         effectively any other container on the same
				         system.

				         Use "-e POSTGRES_PASSWORD=password" to set
				         it in "docker run".
				****************************************************
			EOWARN

			pass=
			authMethod=trust
		fi

		{ echo; echo "host all all all $authMethod"; } | gosu postgres tee -a "$PGDATA/pg_hba.conf" > /dev/null

		# internal start of server in order to allow set-up using psql-client		
		# does not listen on external TCP/IP and waits until start finishes
		gosu postgres pg_ctl -D "$PGDATA" \
			-o "-c listen_addresses='localhost'" \
			-w start

		file_env 'POSTGRES_USER' 'postgres'
		file_env 'POSTGRES_DB' "$POSTGRES_USER"

		psql=( psql -v ON_ERROR_STOP=1 )

		if [ "$POSTGRES_DB" != 'postgres' ]; then
			"${psql[@]}" --username postgres <<-EOSQL
				CREATE DATABASE "$POSTGRES_DB" ;
			EOSQL
			echo
		fi

		if [ "$POSTGRES_USER" = 'postgres' ]; then
			op='ALTER'
		else
			op='CREATE'
		fi
		"${psql[@]}" --username postgres <<-EOSQL
			$op USER "$POSTGRES_USER" WITH SUPERUSER $pass ;
		EOSQL
		echo

		psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh)     echo "$0: running $f"; . "$f" ;;
				*.sql)    echo "$0: running $f"; "${psql[@]}" -f "$f"; echo ;;
				*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
				*)        echo "$0: ignoring $f" ;;
			esac
			echo
		done

		gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop

		echo
		echo 'PostgreSQL init process complete; ready for start up.'
		echo
	fi

	exec gosu postgres "$@" &
	echo 'Giving 10 seconds to postgres to start before starting openBIS'
	sleep 10
	echo 'openBIS starting'
	#su openbis -c /home/openbis/openbis/bin/allup.sh
	exec /etc/init.d/apache2 restart &
	exec gosu openbis /home/openbis/openbis/bin/allup.sh &
	echo 'Infinite wait'
	
	sleep infinity
fi

#QBIC customizations
#if [ -f "/home/openbis/openbis_state/master-data-script.py" ]; then
#	echo "Adding QBIC master-data"
#        exec gosu openbis /home/openbis/openbis/servers/openBIS-server/jetty/bin/register-master-data.sh -s https:://systembiochemistry/openbis/openbis -f /home/openbis/openbis_state/master-data-script.py
#fi
#if [ -d "/home/openbis/openbis_state/etl-scripts" ]; then
#	echo "Enabling QBIC module"
#        exec gosu openbis ln /home/openbis/openbis_state/etl-scripts /home/openbis/openbis/servers/core-plugins/QBIC/1/dss
#fi

## Stop the services
#gosu openbis /home/openbis/openbis/bin/alldown.sh
## Start the services
#gosu openbis /home/openbis/openbis/bin/allup.sh


exec "$@"
