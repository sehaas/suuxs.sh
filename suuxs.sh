#!/usr/bin/env bash

USERAGENT="suuxs.sh"
COOKIES_TXT="suuxs.cookies"
CLEAR_COOKIES="rm -f '${COOKIES_TXT}'"
SUUXS="curl --silent --cookie-jar ${COOKIES_TXT} --cookie ${COOKIES_TXT} -A '${USERAGENT}'"
URL_OVERVIEW="https://www.movescount.com/overview"
URL_LOGIN_PAGE="https://www.movescount.com/auth?redirect_uri=%2foverview"
URL_PREAUTH="https://servicegate.suunto.com/UserAuthorityService/Authenticate?service=Movescount"
URL_AUTH="https://www.movescount.com/services/UserAuthenticated"

if [ ! -f "./suuxs.rc" ]; then
	echo "ERROR: missing configuration file 'suuxs.rc'"
	exit 1
else
	. ./suuxs.rc
fi
URL_GETMOVES="https://uiservices.movescount.com/activityrecordsapi/moves/getmoves?startDateString=${STARTDATE}&endDateString=${ENDDATE}&userId="
URL_EXPORTMOVE="https://www.movescount.com/move/export?format=${FORMAT}&id="

LOGGED_IN=$(${SUUXS} -o /dev/null -w "%{http_code}" "${URL_OVERVIEW}")
if [ "200" -ne "${LOGGED_IN}" ]; then
	echo "retry login"
	${CLEAR_COOKIES}
	${SUUXS} -o /dev/null "${URL_LOGIN_PAGE}"

	TOKEN=$(${SUUXS} -d "{\"EmailAddress\":\"${USERNAME}\",\"Password\":\"${PASSWORD}\"}" -H "Content-Type: application/json" "${URL_PREAUTH}")
	LOGGED_IN=$(${SUUXS} -d "{\"token\":${TOKEN},\"utcOffset\":\"60\",\"redirectUri\":\"/overview\"}" -H "Content-Type: application/json" "${URL_AUTH}" | jq -r '.d.Value' )
	if [ "/overview" != "${LOGGED_IN}" ]; then
		${CLEAR_COOKIES}
		echo "ERROR: login failed"
		exit 2
	fi
	sed -i 's/#HttpOnly_//g' "${COOKIES_TXT}" # wget does not handle this prefix
fi

{ read USERID; read AUTHTOKEN; } < <(${SUUXS} "${URL_OVERVIEW}" | grep token | grep -o "{.*}" | jq -r ".activityFeed.targetUserID, .config.activityRecordsData.token")

MOVES_LIST=$(${SUUXS} -H "Authorization: ${AUTHTOKEN}" "${URL_GETMOVES}${USERID}" | jq '.Moves[].MoveId')
for M in ${MOVES_LIST}; do
	echo "Export move: ${M}"
	wget --quiet --content-disposition --no-clobber --user-agent="${USERAGENT}" --load-cookies "${COOKIES_TXT}" "${URL_EXPORTMOVE}${M}"
done
