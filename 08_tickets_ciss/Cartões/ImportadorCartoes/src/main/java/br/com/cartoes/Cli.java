package br.com.cartoes;
import java.nio.file.*;
public final class Cli {
    public static void main(String[] args) throws Exception {
        switch(args[0]) {
            case "--backfill-values" -> {
                Config config=new Config(Config.home());config.password=System.getenv("CARTOES_DB_PASSWORD");
                if(config.password==null)throw new IllegalArgumentException("Defina CARTOES_DB_PASSWORD apenas para esta execução.");
                try(var c=Database.connect(config)) {
                    c.setAutoCommit(false);int count=0;
                    try {
                        for(String table:new String[]{"TMP.CARTOES_MOVIMENTO","TMP.CARTOES_MOVIMENTO_PROCESSADOS"}) {
                            try(var s=c.prepareStatement("UPDATE "+table+" SET VALOR_BRUTO=? WHERE VALOR_BRUTO IS NULL AND ARQUIVO_HASH=? AND ABA=? AND LINHA=? AND ESTABELECIMENTO=? AND CNPJ=? AND AUTORIZACAO=? AND NSU=? AND NUMERO_MAQUINA=? AND DTMOVIMENTO=?")) {
                                for(int i=1;i<args.length;i++) {
                                    Path path=Path.of(args[i]);String hash=Processor.hash(path);
                                    for(var row:Spreadsheet.read(path)) {
                                        s.setBigDecimal(1,row.valorBruto());s.setString(2,hash);s.setString(3,row.sheet());s.setInt(4,row.row());
                                        s.setString(5,row.estabelecimento());s.setString(6,row.cnpj());s.setString(7,row.autorizacao());s.setString(8,row.nsu());s.setString(9,row.maquina());s.setDate(10,java.sql.Date.valueOf(row.dtmovimento()));
                                        count+=s.executeUpdate();
                                    }
                                }
                            }
                        }
                        c.commit();System.out.println("Valores brutos recuperados da origem: "+count+". Nenhum status alterado ou registro reaberto.");
                    }catch(Exception e){c.rollback();throw e;}
                }
            }
            case "--report-test" -> {
                Config c=new Config(Config.home());c.password=System.getenv("CARTOES_DB_PASSWORD");
                if(c.password==null)throw new IllegalArgumentException("Defina CARTOES_DB_PASSWORD apenas para esta execução.");
                var period=ReportRepository.Period.lastTenDays();var counts=ReportRepository.counts(c,period);System.out.println("Relatório de "+period.start()+" a "+period.end()+": pendentes="+counts.pending()+", status 1="+counts.processed()+", status 2="+counts.unchanged()+", status 3="+counts.missing()+", status 4="+counts.differentTerminal());
                for(int status:new int[]{ReportRepository.PENDING,2,3,4}){var page=ReportRepository.page(c,status,0,period);System.out.println(ReportRepository.displayStatus(status)+": "+page.entries().size()+" registro(s) na primeira página; mais="+page.hasMore());}
            }
            case "--backfill-dates" -> {
                Config config=new Config(Config.home());config.password=System.getenv("CARTOES_DB_PASSWORD");
                try(var c=Database.connect(config)) {
                    c.setAutoCommit(false);int count=0;
                    try(var s=c.prepareStatement("UPDATE TMP.CARTOES_MOVIMENTO SET DTMOVIMENTO=? WHERE DTMOVIMENTO IS NULL AND ARQUIVO_HASH=? AND ABA=? AND LINHA=? AND ESTABELECIMENTO=? AND CNPJ=? AND AUTORIZACAO=? AND NSU=? AND NUMERO_MAQUINA=?")) {
                        for(int i=1;i<args.length;i++) {
                            Path path=Path.of(args[i]);String hash=Processor.hash(path);
                            for(var row:Spreadsheet.read(path)) {
                                s.setDate(1,java.sql.Date.valueOf(row.dtmovimento()));s.setString(2,hash);s.setString(3,row.sheet());s.setInt(4,row.row());
                                s.setString(5,row.estabelecimento());s.setString(6,row.cnpj());s.setString(7,row.autorizacao());s.setString(8,row.nsu());s.setString(9,row.maquina());count+=s.executeUpdate();
                            }
                        }
                        c.commit();System.out.println("Datas recuperadas da origem: "+count);
                    }catch(Exception e){c.rollback();throw e;}
                }
            }
            case "--connection-test" -> {
                Config c=new Config(Config.home());c.password=System.getenv("CARTOES_DB_PASSWORD");
                if(c.password==null)throw new IllegalArgumentException("Defina CARTOES_DB_PASSWORD apenas para esta execução.");
                if(System.getenv("CARTOES_DB_HOST")!=null)c.host=System.getenv("CARTOES_DB_HOST");
                if(System.getenv("CARTOES_DB_PORT")!=null)c.port=System.getenv("CARTOES_DB_PORT");
                try(var connection=Database.connect(c);var statement=connection.createStatement();var result=statement.executeQuery("VALUES CURRENT SERVER")) {
                    if(!result.next())throw new IllegalStateException("Banco não retornou identificação.");
                    System.out.println("OK: conexão DB2 estabelecida. Banco: "+result.getString(1).strip());
                }
            }
            case "--validate" -> {for(int i=1;i<args.length;i++){var rows=Spreadsheet.read(Path.of(args[i]));System.out.println(Path.of(args[i]).getFileName()+": "+rows.size()+" registros; primeiro="+rows.get(0));}}
            case "--db-test" -> {
                Config c=new Config(Config.home());c.password=System.getenv("CARTOES_DB_PASSWORD");
                String hash=java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(java.util.UUID.randomUUID().toString().getBytes()));
                boolean failed=false;
                try{Database.insert(c,hash,"TESTE_ROLLBACK",java.util.List.of(new Spreadsheet.Sale("TESTE","00000000000000","000001",null,"000001","teste",1,java.time.LocalDate.now(),new java.math.BigDecimal("1.00"))));}
                catch(java.sql.SQLException expected){failed=true;}
                if(!failed)throw new AssertionError("Era esperada rejeição de NSU nulo");
                try(var connection=Database.connect(c)) {
                    if(Database.imported(connection,hash))throw new AssertionError("Rollback não removeu marcador");
                    connection.setAutoCommit(false);
                    try {
                        try(var s=connection.prepareStatement("INSERT INTO TMP.CARTOES_IMPORTACAO (ARQUIVO_HASH,ARQUIVO_NOME,QUANTIDADE) VALUES (?,?,1)")) {s.setString(1,hash);s.setString(2,"TESTE_ROLLBACK");s.executeUpdate();}
                        try(var s=connection.prepareStatement("INSERT INTO TMP.CARTOES_MOVIMENTO (ESTABELECIMENTO,CNPJ,AUTORIZACAO,NSU,NUMERO_MAQUINA,ARQUIVO_HASH,ABA,LINHA) VALUES ('TESTE','00000000000000','000001','000002','000003',?,'teste',1)")){s.setString(1,hash);s.executeUpdate();}
                        try(var s=connection.prepareStatement("SELECT AUTORIZACAO,NSU,NUMERO_MAQUINA FROM TMP.CARTOES_MOVIMENTO WHERE ARQUIVO_HASH=?")){s.setString(1,hash);try(var r=s.executeQuery()){if(!r.next()||!r.getString(1).equals("000001")||!r.getString(2).equals("000002")||!r.getString(3).equals("000003"))throw new AssertionError("Identificadores alterados");}}
                    } finally {connection.rollback();}
                    if(Database.imported(connection,hash))throw new AssertionError("Marcador permaneceu após rollback");
                    connection.rollback();
                }
                System.out.println("OK DB2: inserção, zeros iniciais, rejeição de linha inválida e rollback de dados/histórico. Nenhum registro de teste mantido.");
            }
            case "--self-test" -> {
                Path root=Files.createTempDirectory("cartoes-test-"); Config c=new Config(root); c.directory=root.resolve("files");c.password="segredo-teste";c.save();
                if(!Config.load(root).password.equals(c.password))throw new AssertionError("Criptografia");
                if(Files.readString(root.resolve("config.properties")).contains(c.password))throw new AssertionError("Senha exposta");
                c.password="outro";c.save();if(!Config.load(root).password.equals("outro"))throw new AssertionError("Atualização");
                System.out.println("OK: criptografia, leitura, gravação e atualização de configuração.");
            }
            default -> throw new IllegalArgumentException("Comando desconhecido");
        }
    }
}
