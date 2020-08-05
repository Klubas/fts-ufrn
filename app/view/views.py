import os
import logging
from flask import request
from flask_restful import Resource
from flask import render_template, make_response
from app.model.DataBase import DataBase


db = DataBase()


class Index(Resource):
    @staticmethod
    def get():
        headers = {'Content-Type': 'text/html'}
        html = 'index.html'
        return make_response(render_template(html), 200, headers)


class Result(Resource):
    @staticmethod
    def get(search_result):
        headers = {'Content-Type': 'text/html'}
        html = os.path.join('public', 'index.html')
        return make_response(render_template(html), 200, headers)


class Search(Resource):
    @staticmethod
    def post():
        p_json = request.get_json(force=True)

        logging.debug(p_json)

        query = p_json['query'] if 'query' in p_json else None
        search_type = p_json['type'] if 'type' in p_json else None

        sql = \
            'SELECT * FROM "Acervo".busca_acervo(' \
            'p_query=>\'{p_query}\', p_search_type=>\'{p_search_type}\')'.format(
                p_query=query
                , p_search_type=search_type
            )

        logging.info(
            '[AcervoAPI] SQL: {}'.format(sql))

        status = db.execute_sql(sql=sql, as_dict=False)

        logging.info(
            '[AcervoAPI] Response: {}'.format(status))

        if status[0] is False:
            return {'Status': str(status[1][0])}, 11
        else:
            print(status[0])
            if status[0] is True:
                status = status[1][0][0]
                return {'Status': 'OK', 'Response': status}, 200
            else:
                return {'Status': str(status)}, 21

