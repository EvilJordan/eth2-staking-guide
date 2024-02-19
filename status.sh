declare -a validators=("######" "######" "######") # space separated list of validator indexes

ETHDO='/usr/bin/ethdo --connection http://localhost:5051' # path to ethdo binary (https://github.com/wealdtech/ethdo)
NUMEPOCHSINSYNCCOMMITTEE=256
SECONDSINEPOCH=384
GENESISTIMESTAMP=1606795200
NOW=$(date +%s)
IFS=', ' # array split deliniator

chainStatus=$($ETHDO chain status) # capture output of ethdo chain status to know when an epoch is ending
epoch=`echo -e $chainStatus | grep -oEm 2 "Current epoch\: [0-9]{6}$" | sed -E 's/Current epoch\: //g' | tr -d '\n'` # parse out the current epoch

committeeMembers=$($ETHDO synccommittee members)
read -r -a committeeMembersArray <<< "$committeeMembers"

upcomingCommitteeMembers=$($ETHDO synccommittee members --period=next)
read -r -a upcomingCommitteeMembersArray <<< "$upcomingCommitteeMembers"

propserDutiesArray=($($ETHDO proposer duties --epoch $epoch)) # capture validator indexes that are proposing and split into an array - unfortunately adds a newline to the end of the validator index
upcomingPropserDutiesArray=($($ETHDO proposer duties --epoch $(( epoch + 1 )) )) # capture validator indexes that are proposing in the next epoch and split into an array - unfortunately adds a newline to the end of the validator index

# TODO: remove newline from proposer arrays to allow for exact match, instead of substring, below

for validator in "${validators[@]}"
do
	for proposer in "${propserDutiesArray[@]}"
	do
		if [[ $proposer == *$validator* ]]; then # this is imperfect in that if a proposer index contains your index, it will be a false positive
			echo "$validator" 'is going to propose a block this epoch!' | lolcat
		fi
	done
	for proposer in "${upcomingPropserDutiesArray[@]}"
	do
		if [[ $proposer == *$validator* ]]; then # this is imperfect in that if a proposer index contains your index, it will be a false positive
			echo "$validator" 'is going to propose a block NEXT epoch!' | lolcat
		fi
	done
	for committeeMember in "${committeeMembersArray[@]}"
	do
		if [[ "$committeeMember" == "$validator" ]]; then
			echo "$validator" 'is in a sync committee!' | lolcat
		fi
	done
	for upcomingCommitteeMember in "${upcomingCommitteeMembersArray[@]}"
	do
		if [[ "$upcomingCommitteeMember" == "$validator" ]]; then
			echo "$validator" 'is coming up in the next sync committee!' | lolcat
		fi
	done
done

echo '---'

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
