declare -a validators=("######" "######" "######") # space separated list of validator indexes

ETHDO='/usr/bin/ethdo --connection http://localhost:5051' # path to ethdo binary (https://github.com/wealdtech/ethdo)
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

$ETHDO chain status # output chain status to know when an epoch is ending
