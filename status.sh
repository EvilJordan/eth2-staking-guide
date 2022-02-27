declare -a validators=("######" "######" "######") # space separated list of validator indexes

ETHDO='/usr/bin/ethdo --connection http://localhost:5051' # path to ethdo binary (https://github.com/wealdtech/ethdo)
NUMEPOCHSINSYNCCOMMITTEE=256
SECONDSINEPOCH=384
GENESISTIMESTAMP=1606795200
NOW=$(date +%s)
IFS=', ' # array split deliniator

committeeMembers=$($ETHDO synccommittee members)
read -r -a committeeMembersArray <<< "$committeeMembers"

upcomingCommitteeMembers=$($ETHDO synccommittee members --period=next)
read -r -a upcomingCommitteeMembersArray <<< "$upcomingCommitteeMembers"

for index in "${validators[@]}"
do
	for committeeMember in "${committeeMembersArray[@]}"
	do
		if [[ "$committeeMember" == "$index" ]]; then
			echo "$index" 'is in a sync committee!' # woohoo! don't interrupt the staking machine!
		fi
	done
	for upcomingCommitteeMember in "${upcomingCommitteeMembersArray[@]}"
	do
		if [[ "$upcomingCommitteeMember" == "$index" ]]; then
			echo "$index" 'is coming up in the next sync committee!' # wow, congrats!
		fi
	done
done

echo '---'

chainStatus=$($ETHDO chain status) # capture output of ethdo chain status to know when an epoch is ending
epoch=`echo -e $chainStatus | grep -oEm 2 "Current epoch\: [0-9]{6}$" | sed -E 's/Current epoch\: //g' | tr -d '\n'` # parse out the current epoch
NEXTSYNCCOMMITTEETIMESTAMP=$(( NOW + ((epoch % NUMEPOCHSINSYNCCOMMITTEE) * 32 * 12))) # calcuate the timestamp of the next sync committee
echo $chainStatus # output ethdo's chain status
syncCompletion1=`echo "scale=4; $(( epoch % NUMEPOCHSINSYNCCOMMITTEE )) / $NUMEPOCHSINSYNCCOMMITTEE * 100" | bc` # completion percent
syncCompletion2=`echo "scale=2; $syncCompletion1 / 1" | bc` # force to two decimals
numCompletedEpochs=`echo "scale=4; $(( epoch % NUMEPOCHSINSYNCCOMMITTEE )) / $NUMEPOCHSINSYNCCOMMITTEE * 256" | bc`
epochsLeft=`echo "$NUMEPOCHSINSYNCCOMMITTEE - $numCompletedEpochs" | bc` # number of epochs left until next sync committtee
epochTimeLeft=`echo "$epochsLeft * $SECONDSINEPOCH / 1" | bc` # minutes left until next sync committee
nextSyncCommitteeEpoch=`echo "($epoch + $epochsLeft) / 1" | bc` # next sync committee epoch
echo Sync committee completion perc: $syncCompletion2% # output percent left to next sync committee epoch
printf 'Sync committee completion time: %dh%dm%ds\n' $((epochTimeLeft/3600)) $((epochTimeLeft%3600/60)) $((epochTimeLeft%60)) # output time left to next sync committee epoch
echo Next sync committee start epoch: $nextSyncCommitteeEpoch # output next sync committee epoch
