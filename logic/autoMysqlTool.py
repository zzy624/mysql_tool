import mysql.connector
from jinja2 import Environment, FileSystemLoader
from mysql.connector import Error
import sys,os

class MysqlClient(object):
    # MySQL 连接配置
    def __init__(self):
        self.config = {
            'user': '',
            'password': '',
            'host': '',
            'database': '',
            'port': '',
            'raise_on_warnings': '',
        }
        self.data = {
            "Name": "",
            "columns": [],
            "Package": [],
        }
        self.conn = None
        self.cursor = None

    def SetClient(self, username, password, host, port, database):
        self.config = {
            'user': username,
            'password': password,
            'host': host,
            'database': database,
            'port': int(port),
            'raise_on_warnings': True,
        }
        try:
            self.conn = mysql.connector.connect(**self.config)
            self.cursor = self.conn.cursor()
        except Error as e:
            # 捕获连接过程中的异常并输出错误信息
            # print(f"Error: {e}")
            return False, e
        return True, ''

    def __del__(self):
        # 关闭游标和连接
        self.cursor.close()
        self.conn.close()

    def InsertDatas(self, sqli, sqlv, datas):
        insert_query = f'INSERT INTO {self.data["Name"]} ({sqli}) VALUES ({sqlv})'
        self.cursor.executemany(insert_query, datas)
        # 提交事务
        self.conn.commit()

    def ExecSql(self, sql):
        if self.conn:
            self.cursor.execute(sql)
            # 获取查询结果
            # print(self.cursor.fetchall())
            return self.cursor.fetchall()
            # # 打印查询结果
            # for row in result:
            #     print(row)

    def getTableInfo(self, table):
        self.data["columns"] = []
        result = self.ExecSql("show full fields from " + table)
        self.data["Name"] = table
        for row in result:
            # print(row)
            self.data["columns"].append(
                {"Field": row[0],
                 "Type": row[1],
                 "Null": row[3],
                 "Key": row[4],
                 "Default": row[5],
                 "Extra": row[6],
                 "Comment": row[8]},
            )
            if row[1] == "datetime":
                if "time" not in self.data["Package"]:
                    self.data["Package"].append("time")
            if row[1] == "decimal(10,2)":
                if "github.com/shopspring/decimal" not in self.data["Package"]:
                    self.data["Package"].append("github.com/shopspring/decimal")
        # print(self.data)
        return self.data

    def getTempalte(self, table, temp, version):
        if getattr(sys, 'frozen', False):
            # 如果程序是被打包的，使用这个路径
            application_path = os.path.join(sys._MEIPASS, 'templates/' + version)
        else:
            # 如果程序不是打包的，使用当前文件的路径
            application_path = os.path.join(os.path.dirname(os.path.abspath(os.path.dirname(__file__))), 'templates/' + version)
        env = Environment(loader=FileSystemLoader(application_path))
        # 获取的表
        info = self.getTableInfo(table)
        template = env.get_template(temp)
        # 渲染模板，将 GormTagHandler 的实例传递给模板
        output = template.render(info=info, handler=Process())
        return output


class Process(object):
    # 特殊字段
    specilField = ["id", "no", "url", "uuid"]

    def line_to_camel(self, name):
        result = ""
        for v in name.split("_"):
            tmp = v.title()
            if v.lower() in self.specilField:
                tmp = v.upper()
            result += tmp
        return result

    def deal_gorm_tag(self, key, field, type):
        dt = ""
        # if key == "PRI":
        #     dt = "primary_key;"
        dt += f"{field}"
        if type == "decimal(10,2)":
            dt += ";type:decimal(10,2)"
        dt = f"`db:\"{dt}\" json:\"{field}\"`"
        return dt

    def get_type(self, src, null):
        null = "NO"
        if src == "decimal(10,2)":
            return "decimal.Decimal"

        if "(" in src:
            index = src.index("(")
            type_prefix = src[:index]
            if type_prefix == "varchar":
                return "string" if null == "NO" else "*string"
            elif type_prefix in ["float", "double"]:
                return "float64" if null == "NO" else "*float64"
            else:
                return "string" if null == "NO" else "*string"
        else:
            if src in ["bigint", "tinyint", "int", "bigint unsigned", "tinyint unsigned"]:
                return "int" if null == "NO" else "*int"
            elif src in ["datetime", "timestamp"]:
                return "types.XTime" if null == "NO" else "types.XTime"
            elif src in ["text", "longtext"]:
                return "string" if null == "NO" else "*string"
            else:
                return "string" if null == "NO" else "*string"


if __name__ == '__main__':
    M = MysqlClient()
    M.SetClient("root", "12345678", "127.0.0.1", "3306", "zzy")

    print(M.getTableInfo("setting"))

    data = [[ 'iLBCiCV1J83tY24dCuIL', '', '1', '2023-12-13 23:35:09', '2023-12-13 23:35:09'],
            [ 'X4j8oYDzO2013YM9CvUy', '', '1', '2023-12-13 23:35:09', '2023-12-13 23:35:09']]
    M.InsertDatas("`name`,`data`,`status`,`created_at`,`updated_at`", "%s,%s,%s,%s,%s", data)

    # # 创建 Jinja2 环境，指定模板文件夹
    # env = Environment(loader=FileSystemLoader('template'))
    # # 获取的表
    # info = M.getTableInfo("trade")
    # # 从模板文件中加载模板
    # for tem in ["template", "template_ex"]:
    #     template = env.get_template(tem)
    #     # 渲染模板，将 GormTagHandler 的实例传递给模板
    #     output = template.render(info=info, handler=Process())
    #     # 打印渲染后的结果
    #     with open(f'template/go_src/{info["Name"]}{tem.split("template")[1]}.go', 'w') as file:
    #         file.write(output)
