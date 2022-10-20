#!flask/bin/python
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
from dynamodb.connectionManager     import ConnectionManager
from dynamodb.gameController        import GameController
from models.game                    import Game
from uuid                           import uuid4
from flask                          import Flask, render_template, request, session, flash, redirect, jsonify, json
from configparser                   import ConfigParser
import os, time, sys, argparse

application = Flask(__name__)
application.debug = True
application.secret_key = str(uuid4())

"""
   Configure the application according to the command line args and config files
"""

cm = None

parser = argparse.ArgumentParser(description='Run the TicTacToe sample app', prog='application.py')
parser.add_argument('--config', help='Path to the config file containing application settings. Cannot be used if the CONFIG_FILE environment variable is set instead')
parser.add_argument('--mode', help='Whether to connect to a DynamoDB service endpoint, or to connect to DynamoDB Local. In local mode, no other configuration ' \
                    'is required. In service mode, AWS credentials and endpoint information must be provided either on the command-line or through the config file.',
                    choices=['local', 'service'], default='service')
parser.add_argument('--endpoint', help='An endpoint to connect to (the host name - without the http/https and without the port). ' \
                    'When using DynamoDB Local, defaults to localhost. If the USE_EC2_INSTANCE_METADATA environment variable is set, reads the instance ' \
                    'region using the EC2 instance metadata service, and contacts DynamoDB in that region.')
parser.add_argument('--port', help='The port of DynamoDB Local endpoint to connect to.  Defaults to 8000', type=int)
parser.add_argument('--serverPort', help='The port for this Flask web server to listen on.  Defaults to 5000 or whatever is in the config file. If the SERVER_PORT ' \
                    'environment variable is set, uses that instead.', type=int)
args = parser.parse_args()

configFile = args.config
config = None
if 'CONFIG_FILE' in os.environ:
    if configFile is not None:
        raise Exception('Cannot specify --config when setting the CONFIG_FILE environment variable')
    configFile = os.environ['CONFIG_FILE']
if configFile is not None:
    config = ConfigParser()
    config.read(configFile)

# Read environment variable for whether to read config from EC2 instance metadata
use_instance_metadata = ""
if 'USE_EC2_INSTANCE_METADATA' in os.environ:
    use_instance_metadata = os.environ['USE_EC2_INSTANCE_METADATA']

cm = ConnectionManager(mode=args.mode, config=config, endpoint=args.endpoint, port=args.port, use_instance_metadata=use_instance_metadata)
controller = GameController(cm)

serverPort = args.serverPort
if config is not None:
    if config.has_option('flask', 'secret_key'):
        application.secret_key = config.get('flask', 'secret_key')
    if serverPort is None:
        if config.has_option('flask', 'serverPort'):
            serverPort = config.get('flask', 'serverPort')

# Default to environment variables for server port - easier for elastic beanstalk configuration
if 'SERVER_PORT' in os.environ:
    serverPort = int(os.environ['SERVER_PORT'])

if serverPort is None:
    serverPort = 5000

"""
   Define the urls and actions the app responds to
"""

@application.route('/logout')
def logout():
    """
    Method associated to the route '/logout' that sets the logged in
    user of the session to None.
    """
    session["username"] = None
    return redirect("/index")

@application.route('/table', methods=["GET", "POST"])
def createTable():
    cm.createGamesTable()

    while controller.checkIfTableIsActive() == False:
        time.sleep(3)

    return redirect('/index')

@application.route('/')
@application.route('/index', methods=["GET", "POST"])
def index():
    """
    Method associated to both routes '/' and '/index' and accepts
    post requests for when a user logs in.  Updates the user of
    the session to the person who logged in.  Also populates 3 tables for game invites, games in progress, and
    games finished by the logged in user (if there is one).
    """

    if session == {} or session.get("username", None) == None:
        form = request.form
        if form:
            formInput = form["username"]
            if formInput and formInput.strip():
                session["username"] = request.form["username"]
            else:
                session["username"] = None
        else:
            session["username"] = None

    if request.method == "POST":
        return redirect('/index')

    inviteGames = controller.getGameInvites(session["username"])
    tableStatus = controller.checkIfTableIsActive()
    if not tableStatus:
        flash("Table has not been created yet, please follow this link to create table.")
        return render_template("table.html",
                                user="")

    # Don't attempt to iterate over inviteGames until AFTER None test
    if inviteGames and len(inviteGames) > 0:
        inviteGames = [Game(inviteGame) for inviteGame in inviteGames]
    else:
        inviteGames = []

    inProgressGames = controller.getGamesWithStatus(session["username"], "IN_PROGRESS")
    if inProgressGames and len(inProgressGames) > 0:
        inProgressGames = [Game(inProgressGame) for inProgressGame in inProgressGames]
    else:
        inProgressGames = []

    finishedGames   = controller.getGamesWithStatus(session["username"], "FINISHED")
    if finishedGames and len(finishedGames) > 0:
        fs = [Game(finishedGame) for finishedGame in finishedGames]
    else:
        fs = []

    return render_template("index.html",
            user=session["username"],
            invites=inviteGames,
            inprogress=inProgressGames,
            finished=fs)

@application.route('/create')
def create():
    """
    The route associated with the create button on the index page.
    Checks for a logged in user before proceeding to create a game.
    """
    if session.get("username", None) == None:
        flash("Need to login to create game")
        return redirect("/index")
    return render_template("create.html",
                            user=session["username"])

@application.route('/play', methods=["POST"])
def play():
    """
    This method receives the post request from the form on the
    '/create' page.

    Basic validation for the name of the player invited.

    Calls the createNewGame method from the gameController and either
    informs you that the creation failed or takes you to the game's page.
    """
    form = request.form
    if form:
        creator = session["username"]
        gameId  = str(uuid4())
        invitee = form["invitee"].strip()

        if not invitee or creator == invitee:
            flash("Use valid a name (not empty or your name)")
            return redirect("/create")

        if controller.createNewGame(gameId, creator, invitee):
            return redirect("/game="+gameId)

    flash("Something went wrong creating the game.")
    return redirect("/create")

@application.route('/game=<gameId>')
def game(gameId):
    """
    Method associated the with the '/game=<gameId>' route where the
    gameId is in the URL.

    Validates that the gameId actually exists.

    Checks to see if the game has been finished.

    Gets the state of the board and updates the visual representation
    accordingly.

    Displays a bit of extra information like turn, status, and gameId.
    """
    if session.get("username", None) == None:
        flash("Need to login")
        return redirect("/index")

    item = controller.getGame(gameId)
    if item == None:
        flash("That game does not exist.")
        return redirect("/index")


    boardState = controller.getBoardState(item)
    result = controller.checkForGameResult(boardState, item, session["username"])

    if result != None:
        if controller.changeGameToFinishedState(item, result, session["username"]) == False:
            flash("Some error occured while trying to finish game.")

    game = Game(item)
    status   = game.status
    turn     = game.turn

    if game.getResult(session["username"]) == None:
        if (turn == game.o):
            turn += " (O)"
        else:
            turn += " (X)"
    else:
        result = game.getResult(session["username"])

    gameData = {'gameId': gameId, 'status': game.status, 'turn': game.turn, 'board': boardState};
    gameJson = json.dumps(gameData)
    return render_template("play.html",
                            gameId=gameId,
                            gameJson=gameJson,
                            user=session["username"],
                            status=status,
                            turn=turn,
                            opponent=game.getOpposingPlayer(session["username"]),
                            result=result,
                            TopLeft=boardState[0],
                            TopMiddle=boardState[1],
                            TopRight=boardState[2],
                            MiddleLeft=boardState[3],
                            MiddleMiddle=boardState[4],
                            MiddleRight=boardState[5],
                            BottomLeft=boardState[6],
                            BottomMiddle=boardState[7],
                            BottomRight=boardState[8])

@application.route('/gameData=<gameId>')
def gameData(gameId):
    """
    Method associated the with the '/gameData=<gameId>' route where the
    gameId is in the URL.

    Validates that the gameId actually exists.

    Returns a JSON representation of the game to support AJAX to poll to see
    if the page should be refreshed
    """
    item = controller.getGame(gameId)
    boardState = controller.getBoardState(item)
    if item == None:
        return jsonify(error='That game does not exist')

    game = Game(item)
    return jsonify(gameId = gameId,
                   status = game.status,
                   turn = game.turn,
                   board = boardState)

@application.route('/accept=<invite>', methods=["POST"])
def accept(invite):
    """
    Method associated with the route '/accept=<invite>' where invite
    is the game that you have chosen to accept.

    Updates the game status to IN_PROGRESS and proceeds to the game's page.
    """
    gameId = request.form["response"]
    game = controller.getGame(gameId)["Item"]

    if game == None:
        flash("That game does not exist anymore.")
        redirect("/index")

    if not controller.acceptGameInvite(game):
        flash("Error validating the game...")
        redirect("/index")

    return redirect("/game="+game["GameId"])

@application.route('/reject=<invite>', methods=["POST"])
def reject(invite):
    """
    Method associated with the route '/reject=<invite>' where invite
    is the game that you have chosen to reject.

    Deletes the item associated with the invite from the Games table.
    """
    gameId = request.form["response"]
    game = controller.getGame(gameId)["Item"]

    if game == None:
        flash("That game doesn't exist anymore.")
        redirect("/index")

    if not controller.rejectGameInvite(game):
        flash("Something went wrong when deleting invite.")
        redirect("/index")

    return redirect("/index")

@application.route('/select=<gameId>', methods=["POST"])
def selectSquare(gameId):
    """
    Method associated with the route '/select=<gameId>' where gameId
    is the game you tried to make a move on.

    Tries to perform a conditional write on the item associated with this
    gameId. If it fails then user receives a message describing the
    potential errors that he made.
    """
    value = request.form["cell"]

    item = controller.getGame(gameId)
    if item == None:
        flash("This is not a valid game.")
        return redirect("/index")

    if controller.updateBoardAndTurn(item, value, session["username"]) == False:
        flash("You have selected a square either when \
                it's not your turn, \
                the square is already selected, \
                or the game is not 'In-Progress'.",
                "updateError")
        return redirect("/game="+gameId)

    return redirect("/game="+gameId)

if __name__ == "__main__":
    if cm:
        application.run(debug = True, port=serverPort, host='0.0.0.0')
