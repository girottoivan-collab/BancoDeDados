package br.com.cartoes;

import java.sql.*;
import java.time.LocalDate;
import java.util.*;

final class ReportRepository {
    static final int PAGE_SIZE=100;
    static final int PENDING=-1;
    record Period(LocalDate start,LocalDate end){
        Period {if(start==null || end==null || start.isAfter(end))throw new IllegalArgumentException("A data inicial deve ser menor ou igual à data final.");}
        static Period lastTenDays(){LocalDate today=LocalDate.now();return new Period(today.minusDays(9),today);}
    }
    record Counts(long pending,long processed,long unchanged,long missing,long differentTerminal) {}
    static String statusLabel(int status){return switch(status){case PENDING->"Pendentes de processamento";case 1->"Processado";case 2->"Processado e não alterado";case 3->"Processado e não encontrado";case 4->"Processado terminal diferente";default->throw new IllegalArgumentException("Status fora do relatório: "+status);};}
    static String displayStatus(int status){return status==PENDING?statusLabel(status):status+" — "+statusLabel(status);}
    record Entry(long id,int status,String estabelecimento,String cnpj,String autorizacao,String nsu,
                 String maquina,LocalDate movimento,String arquivo,String aba,int linha,
                 Timestamp importado,Timestamp processado,Integer encontrados,Integer alterados,java.math.BigDecimal valorBruto) {
        @Override public String toString(){return (movimento==null?"Sem data":movimento)+" | "+estabelecimento+" | NSU "+nsu+" | #"+id;}
    }
    record Page(List<Entry> entries,boolean hasMore) {}
    static Counts counts(Config config) throws Exception {return counts(config,Period.lastTenDays());}
    static Counts counts(Config config,Period period) throws Exception {
        long pending=0,processed=0,unchanged=0,missing=0,differentTerminal=0;
        String sql="SELECT CAST(-1 AS SMALLINT) AS STATUS,COUNT(*) FROM TMP.CARTOES_MOVIMENTO WHERE DTMOVIMENTO BETWEEN ? AND ? UNION ALL SELECT STATUS,COUNT(*) FROM TMP.CARTOES_MOVIMENTO_PROCESSADOS WHERE STATUS IN (1,2,3,4) AND DTMOVIMENTO BETWEEN ? AND ? GROUP BY STATUS";
        try(Connection c=Database.connect(config);PreparedStatement s=c.prepareStatement(sql)) {
            bindPeriod(s,1,period);bindPeriod(s,3,period);s.setQueryTimeout(30);
            try(ResultSet r=s.executeQuery()){while(r.next()){switch(r.getInt(1)){case PENDING->pending=r.getLong(2);case 1->processed=r.getLong(2);case 2->unchanged=r.getLong(2);case 3->missing=r.getLong(2);case 4->differentTerminal=r.getLong(2);}}}
        }
        return new Counts(pending,processed,unchanged,missing,differentTerminal);
    }
    static Page page(Config config,int status,long after) throws Exception {return page(config,status,after,Period.lastTenDays());}
    static Page page(Config config,int status,long after,Period period) throws Exception {
        if(status!=PENDING && status!=2 && status!=3 && status!=4)throw new IllegalArgumentException("Relatório permitido para pendentes e status 2, 3 e 4.");
        List<Entry> entries=new ArrayList<>();
        String sql=status==PENDING
            ?"SELECT P.ID,CAST(-1 AS SMALLINT) AS STATUS,P.ESTABELECIMENTO,P.CNPJ,P.AUTORIZACAO,P.NSU,P.NUMERO_MAQUINA,P.DTMOVIMENTO,I.ARQUIVO_NOME,P.ABA,P.LINHA,P.IMPORTADO_EM,CAST(NULL AS TIMESTAMP) AS PROCESSADO_EM,CAST(NULL AS INTEGER) AS QTD_ENCONTRADOS,CAST(NULL AS INTEGER) AS QTD_ALTERADOS,P.VALOR_BRUTO FROM TMP.CARTOES_MOVIMENTO P LEFT JOIN TMP.CARTOES_IMPORTACAO I ON I.ARQUIVO_HASH=P.ARQUIVO_HASH WHERE P.ID>? AND P.DTMOVIMENTO BETWEEN ? AND ? ORDER BY P.ID FETCH FIRST 101 ROWS ONLY"
            :"SELECT P.ID,P.STATUS,P.ESTABELECIMENTO,P.CNPJ,P.AUTORIZACAO,P.NSU,P.NUMERO_MAQUINA,P.DTMOVIMENTO,I.ARQUIVO_NOME,P.ABA,P.LINHA,P.IMPORTADO_EM,P.PROCESSADO_EM,P.QTD_ENCONTRADOS,P.QTD_ALTERADOS,P.VALOR_BRUTO FROM TMP.CARTOES_MOVIMENTO_PROCESSADOS P LEFT JOIN TMP.CARTOES_IMPORTACAO I ON I.ARQUIVO_HASH=P.ARQUIVO_HASH WHERE P.STATUS=? AND P.ID>? AND P.DTMOVIMENTO BETWEEN ? AND ? ORDER BY P.ID FETCH FIRST 101 ROWS ONLY";
        try(Connection c=Database.connect(config);PreparedStatement s=c.prepareStatement(sql)) {
            if(status==PENDING){s.setLong(1,after);bindPeriod(s,2,period);}else{s.setInt(1,status);s.setLong(2,after);bindPeriod(s,3,period);}s.setQueryTimeout(30);
            try(ResultSet r=s.executeQuery()){while(r.next()){
                java.sql.Date date=r.getDate(8);
                entries.add(new Entry(r.getLong(1),r.getInt(2),r.getString(3),r.getString(4),r.getString(5),r.getString(6),r.getString(7),date==null?null:date.toLocalDate(),r.getString(9),r.getString(10),r.getInt(11),r.getTimestamp(12),r.getTimestamp(13),(Integer)r.getObject(14),(Integer)r.getObject(15),r.getBigDecimal(16)));
            }}
        }
        boolean more=entries.size()>PAGE_SIZE;
        if(more)entries.remove(entries.size()-1);
        return new Page(List.copyOf(entries),more);
    }
    static void bindPeriod(PreparedStatement statement,int index,Period period) throws SQLException {statement.setDate(index,java.sql.Date.valueOf(period.start()));statement.setDate(index+1,java.sql.Date.valueOf(period.end()));}
}
