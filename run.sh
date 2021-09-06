#!/bin/bash
# params:
#        $1: clair readiness timeout in senconds

docker-compose -f $GITHUB_ACTION_PATH/docker-compose.yml up -d registry postgres

timetorun=30
stoptime=$((timetorun + $(date +%s)))

function checkClairStatus() {
    DONE=$(docker logs -n 1000 clair 2>&1 | jq 'select(.message=="starting background updates")' -)

    if [ -z "$DONE" ]; then
	return 0;
    else
        return 1;
    fi
}

echo "Checking postgres status..."
while [ true ]
do 
    if [[ $(date +%s) > $stoptime ]]; then
        echo "[Error]: Timeout waiting for Postgres"
        docker logs -n 1000 postgres
        exit 1;
    fi
    
    docker exec postgres psql -U clair -d clair &> /dev/null 2>&1
    
    if [[ "$?" -eq 0 ]]; then
        echo "Postgres is ready!"
        docker-compose -f $GITHUB_ACTION_PATH/docker-compose.yml up -d clair
        break;
    fi
    
    sleep 1;
done

timetorun=$1
stoptime=$((timetorun + $(date +%s)))

echo "Checking clair status..."
while [ true ]
do  
    if [[ $(date +%s) > $stoptime ]]; then
        echo "[Error]: Timeout waiting for Clair"
        docker logs -n 1000 clair
        exit 1;
    fi

    checkClairStatus
    STATUS=$?
    
    curl --max-time 5 http://localhost:6060 &> /dev/null 2>&1
    
    if [[ "$?" -eq 0 && $STATUS -eq 1 ]]; then
        echo "Clair is ready!"
        break;
    fi
    
    sleep 5;
    echo "Waiting for Clair to be ready..."
done

