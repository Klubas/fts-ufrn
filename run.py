#!/usr/bin/env python3
import sys, os
import argparse

from flask import Flask
from flask_restful import Api
from app.views import Index, Search, Result

if __name__ == '__main__':

    app = Flask(__name__, template_folder=os.path.join('app', 'templates'))
    api = Api(app)

    # add resources
    api.add_resource(Index, '/')
    api.add_resource(Search, '/busca_acervo/')
    api.add_resource(Result, '/busca_acervo/resultado')

    try:

        parser = argparse.ArgumentParser(
            description="Acervo UFRN"
        )

        parser.add_argument(
            '--hostname'
            , metavar='hostname:port'
            , type=str
            , help="hostname and port number for the server in the format: <hostname>:<port>"
            , nargs='?'
        )

        parser.add_argument(
            '--debug'
            , help="Run in debug mode"
            , action='store_true'
        )

        args = parser.parse_args()

        print(args)

        if args.hostname:
            hostname = args.hostname.split(":")
            host = hostname[0]
            port = int(hostname[1])
        else:
            sys.exit(-1)

        # app.config['EXPLAIN_TEMPLATE_LOADING'] = True

        app.run(
            host=host
            , port=port
            , debug=args.debug
        )

    except (KeyboardInterrupt, SystemExit):
        print("\nExiting...")

else:
    sys.exit()