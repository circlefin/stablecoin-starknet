# Copyright 2025 Circle Internet Group, Inc. All rights reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

LOG_FILE="$PWD/starknet-node.log"

echo "Starting Starknet node..."

starknet-devnet --seed=0 &> $LOG_FILE &

WAIT_TIME=120
echo ">> Waiting for Starknet node to come online within $WAIT_TIME seconds..."

ELAPSED=0
SECONDS=0
while [[ "$ELAPSED" -lt "$WAIT_TIME" ]]
do
  HEALTHCHECK_STATUS_CODE="$(curl -k -s -o /dev/null -w %{http_code} http://localhost:5050/is_alive)"
  if [[ "$HEALTHCHECK_STATUS_CODE" -eq 200 ]]
  then
    echo ">> Starknet node is started after $ELAPSED seconds!"
    cat $LOG_FILE
    exit 0
  fi

  if [[ $(( ELAPSED % 10 )) == 0 && "$ELAPSED" > 0 ]]
  then
    echo ">> Waiting for Starknet node for $ELAPSED seconds.. (Status: $HEALTHCHECK_STATUS_CODE)"
    echo ">> Last few lines of log:"
    tail -5 $LOG_FILE 2>/dev/null || echo "   No log content yet"
  fi

  sleep 1
  ELAPSED=$SECONDS
done

echo ">> Starknet node failed to start within $WAIT_TIME seconds!"
echo ">> Showing log file contents:"
cat $LOG_FILE
exit 1
