'''
.. module:: db
   :synopsis: This module includes functions related to PostgreSQL / PostGIS queries.
.. moduleauthor:: Marc Wieland <mwieland@gfz-potsdam.de>
   :organization: GFZ German Research Centre for Geosciences
'''

import psycopg2

class Db(object):
    
    def __init__(self, db_connect):
        try:
            self.conn=psycopg2.connect(db_connect)
            self.conn.autocommit = True
        except:
            print 'not able to connect to database'

        self.cur = self.conn.cursor()

    
    def __del__(self):
        self.cur.close()
        self.conn.close()

        
    def query(self, query):
        '''Issue a PostgreSQL query that gives no rows back. \n
           This function provides the general interface to perform database transactions in PostgreSQL.
        
        :param query: SQL query (String)
        :returns: None.
        
        >>> dbconn = Db("host=localhost port=5432 dbname=classification_test user=postgres password=***")
        >>> res = dbconn.query("UPDATE table SET x=1 WHERE seg_id=1;")
        >>> del dbconn

        Author: Marc Wieland | Last modified: 10/03/2015 
        '''
        
        self.cur.execute(query)
        
        return None

    
    def queryRes(self, query):
        
        '''Issue a PostgreSQL query that gives rows back. \n           
           This function provides the general interface to issue queries in PostgreSQL and get rows.
        
        :param query: SQL query (String)
        :returns: Query result.
        
        >>> dbconn = Db("host=localhost port=5432 dbname=classification_test user=postgres password=***")
        >>> rids = []
        >>> res = dbconn.queryRes("SELECT distinct(rid) FROM table ORDER BY rid;")
        >>> for r in res: 
                rids.append(r[0])
        >>> del dbconn
        
        Author: Marc Wieland | Last modified: 10/03/2015  
        '''
        
        self.cur.execute(query)
        res = self.cur.fetchall()
        
        return res
