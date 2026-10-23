package br.com.cartoes;

import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;
import java.util.function.Consumer;

final class Processor {
    final Consumer<String> log;
    final Map<Path,String> observed=new HashMap<>();
    Processor(Consumer<String> log){this.log=log;}
    static String hash(Path path) throws Exception {
        MessageDigest digest=MessageDigest.getInstance("SHA-256");
        try(var in=Files.newInputStream(path)){ byte[] b=new byte[65536]; int n; while((n=in.read(b))!=-1) digest.update(b,0,n); }
        return HexFormat.of().formatHex(digest.digest());
    }
    void scan(Config c, boolean manual) throws Exception {
        c.folders();
        int pending=0,completed=0,waiting=0,errors=0;
        try(var files=Files.list(c.directory.resolve("Pendentes"))) {
            for(Path file:files.sorted().toList()) {
                String name=file.getFileName().toString(); String lower=name.toLowerCase(Locale.ROOT);
                if(!Files.isRegularFile(file) || name.startsWith("~$") || name.startsWith(".") || !(lower.endsWith(".xlsx") || lower.endsWith(".xls"))) continue;
                pending++;
                if(Files.exists(file.resolveSibling(".~lock."+name+"#")) || Files.exists(file.resolveSibling("~$"+name))) {waiting++;log.accept("Em uso: "+name);continue;}
                String fingerprint=Files.size(file)+":"+Files.getLastModifiedTime(file).toMillis();
                String before=observed.put(file,fingerprint);
                if(!manual && (!fingerprint.equals(before) || System.currentTimeMillis()-Files.getLastModifiedTime(file).toMillis()<5000)) {waiting++;log.accept("Aguardando estabilização: "+name);continue;}
                Path snapshot=null;
                try {
                    snapshot=Files.createTempFile(c.home,"import-",lower.endsWith(".xlsx")?".xlsx":".xls");
                    Files.copy(file,snapshot,StandardCopyOption.REPLACE_EXISTING);
                    String digest=hash(snapshot);
                    var rows=Spreadsheet.read(snapshot);
                    if(!digest.equals(hash(file))) throw new IllegalStateException("Arquivo alterado durante leitura; será tentado novamente.");
                    boolean inserted=Database.insert(c,digest,name,rows);
                    if(!digest.equals(hash(file))) throw new IllegalStateException("Arquivo mudou após gravação; original mantido em Pendentes.");
                    Path target=c.directory.resolve("Processadas").resolve(name);
                    if(Files.exists(target)) target=target.resolveSibling(UUID.randomUUID()+"_"+name);
                    Files.move(file,target);
                    observed.remove(file);
                    completed++;
                    log.accept((inserted?"Importado: ":"Já importado, movido: ")+name+" | "+rows.size()+" registros");
                } catch(Exception e){errors++;log.accept("ERRO "+name+": "+e.getMessage()+" — mantido em Pendentes.");}
                finally {if(snapshot!=null) Files.deleteIfExists(snapshot);}
            }
        }
        if(pending==0)log.accept("Nenhuma planilha pendente. Monitoramento em execução.");
        log.accept("Resumo: "+pending+" planilha(s) encontrada(s), "+completed+" processada(s), "+waiting+" aguardando, "+errors+" com erro.");
    }
}
