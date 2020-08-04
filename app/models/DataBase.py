import json
import logging
import os
from dotenv import load_dotenv
from pydal import DAL


class DataBase:

    def __init__(self, dbname='postgres', schema='Acervo', pool_size=5):

        load_dotenv()

        self.dbname = dbname
        self.schema = schema
        self.username = os.getenv("DBUSERNAME")
        self.password = os.getenv("DBPASS")
        self.host = os.getenv("DBHOST")
        self.port = os.getenv("DBPORT")
        self.folder = 'Resources' + os.sep + 'database'

        self.dbinfo = \
            'postgres://' + str(self.username) + ':' + str(self.password) + '@' \
            + str(self.host) + ':' + str(self.port) + '/' + str(self.dbname)

        self.db = DAL(
            self.dbinfo,
            folder=self.folder,
            pool_size=pool_size,
            migrate=False,
            attempts=1
        )
        self.connection = None

    def execute_sql(self, sql, as_dict=True):
        retorno = list()
        try:
            retorno = self.db.executesql(query=sql, as_dict=as_dict)
            self.db.commit()
            logging.debug('[DataBase] status=' + str(True))
            logging.debug('[DataBase] sql=' + str(sql))
            logging.debug('[DataBase] retorno=' + str(retorno))
            prc = True, retorno, str(self.db._lastsql)

        except Exception as e:
            self.db.rollback()
            logging.debug('[DataBase] status=' + str(False))
            logging.debug('[DataBase] sql=' + str(sql))
            logging.debug('[DataBase] exception=' + str(e))
            retorno.append(e)
            prc = False, retorno, str(sql)

        except:
            e = 'Exceção não tratada'
            logging.debug('[DataBase] status=' + str(False))
            logging.debug('[DataBase] sql=' + str(sql))
            logging.debug('[DataBase] exception2=' + str(e))
            retorno.append(e)
            prc = False, e, str(sql)

        return prc

    def __conectar_banco__(self):
        try:
            self.connection = self.db.__call__()
        except Exception as e:
            logging.debug('[DataBase] ' + str(e))
        return self

    def definir_schema(self, schema):
        self.schema = schema
        self.execute_sql("SET search_path TO " + self.schema, as_dict=False)

    def fechar_conexao(self):
        self.db.close()
