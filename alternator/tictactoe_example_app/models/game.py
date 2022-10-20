# Copyright 2014. Amazon Web Services, Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
from datetime             import datetime

class Game:
    """
    This Game class acts as a wrapper on top of an item in the Games table.
    Each of the fields in the table is of a String type.
    GameId is the primary key.
    HostId-StatusDate, Opponent-StatusDate are Global Secondary Indexes that are Hash-Range Keys.
    The other attributes are used to maintain game state.
    """
    def __init__(self, item):
        if "Item" in item.keys():
            item2=item["Item"]
        else:
            item2 = item
        self.item = item2
        self.gameId       = item2["GameId"]
        self.hostId       = item2["HostId"]
        self.opponent     = item2["OpponentId"]
        self.statusDate   = item2["StatusDate"].split("_")
        self.o            = item2["OUser"]
        self.turn         = item2["Turn"]

    def getStatus(self):
        status = self.statusDate[0]
        if len(self.statusDate) > 2:
            status += "_" + self.statusDate[1]
        return status
    status = property(getStatus)

    def getDate(self):
        index = 1
        if len(self.statusDate) > 2:
            index = 2
        date = datetime.strptime(self.statusDate[index],'%Y-%m-%d %H:%M:%S.%f')
        return datetime.strftime(date, '%Y-%m-%d %H:%M:%S')
    date = property(getDate)

    def __cmp__(self, otherGame):
        if otherGame == None:
            return cmp(self.statusDate[1], None)
        return cmp(self.statusDate[1], otherGame.statusDate[1])

    def getOpposingPlayer(self, current_player):
        if current_player == self.hostId:
            return self.opponent
        else:
            return self.hostId

    def getResult(self, current_player):
        if "Result" not in self.item.keys():
            return None
        if self.item["Result"] == None:
            return None
        if self.item["Result"] == "Tie":
            return "Tie"
        if self.item["Result"] == current_player:
            return "Win"
        else:
            return "Lose"

