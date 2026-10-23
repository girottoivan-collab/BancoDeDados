package br.com.cartoes;

import java.sql.*;
import java.util.List;

final class Database {
    static Connection connect(Config c) throws Exception {
        Class.forName("com.ibm.db2.jcc.DB2Driver");
        java.util.Properties p=new java.util.Properties(); p.setProperty("user",c.user); p.setProperty("password",c.password);
        p.setProperty("loginTimeout","10"); p.setProperty("blockingReadConnectionTimeout","30");
        return DriverManager.getConnection("jdbc:db2://"+c.host+":"+c.port+"/"+c.database,p);
    }
    static boolean imported(Connection c,String hash) throws SQLException {
        try(PreparedStatement s=c.prepareStatement("SELECT 1 FROM TMP.CARTOES_IMPORTACAO WHERE ARQUIVO_HASH=?")) {
            s.setString(1,hash); try(ResultSet r=s.executeQuery()){return r.next();}
        }
    }
    static boolean insert(Config config,String hash,String name,List<Spreadsheet.Sale> rows) throws Exception {
        try(Connection c=connect(config)) {
            c.setAutoCommit(false);
            try {
                if(imported(c,hash)){c.rollback(); return false;}
                try(PreparedStatement s=c.prepareStatement("INSERT INTO TMP.CARTOES_IMPORTACAO (ARQUIVO_HASH,ARQUIVO_NOME,QUANTIDADE) VALUES (?,?,?)")) {
                    s.setString(1,hash); s.setString(2,name); s.setInt(3,rows.size()); s.executeUpdate();
                }
                try(PreparedStatement s=c.prepareStatement("INSERT INTO TMP.CARTOES_MOVIMENTO (ESTABELECIMENTO,CNPJ,AUTORIZACAO,NSU,NUMERO_MAQUINA,ARQUIVO_HASH,ABA,LINHA,DTMOVIMENTO,VALOR_BRUTO) VALUES (?,?,?,?,?,?,?,?,?,?)")) {
                    int count=0;
                    for(var row:rows) {
                        s.setString(1,row.estabelecimento()); s.setString(2,row.cnpj()); s.setString(3,row.autorizacao()); s.setString(4,row.nsu()); s.setString(5,row.maquina());
                        s.setString(6,hash); s.setString(7,row.sheet()); s.setInt(8,row.row()); s.setDate(9,Date.valueOf(row.dtmovimento()));s.setBigDecimal(10,row.valorBruto());s.addBatch();
                        if(++count%500==0) s.executeBatch();
                    }
                    if(count%500!=0) s.executeBatch();
                }
                c.commit(); return true;
            } catch(Exception e){c.rollback(); throw e;}
        }
    }
}
