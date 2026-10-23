package br.com.cartoes;

import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.*;
import javax.crypto.*;
import javax.crypto.spec.*;

final class Config {
    final Path home;
    String host="10.250.4.45", port="50013", database="BIGSM", user="dba", password="";
    Path directory; int seconds=60;
    Config(Path home) { this.home=home; directory=home.resolve("Planilhas"); }
    static Path home() throws Exception {
        String launcher=System.getProperty("jpackage.app-path");
        if(launcher!=null) return Path.of(launcher).toAbsolutePath().getParent();
        return Path.of(App.class.getProtectionDomain().getCodeSource().getLocation().toURI()).toAbsolutePath().getParent();
    }
    static Config load(Path home) throws Exception {
        Config c=new Config(home); Path f=home.resolve("config.properties");
        if(!Files.exists(f)) return c;
        Properties p=new Properties(); try(var in=Files.newInputStream(f)){p.load(in);}
        c.host=p.getProperty("host"); c.port=p.getProperty("port"); c.database=p.getProperty("database"); c.user=p.getProperty("user");
        c.directory=Path.of(p.getProperty("directory")); c.seconds=Integer.parseInt(p.getProperty("seconds"));
        c.password=c.decrypt(p.getProperty("password.encrypted")); c.validate(); return c;
    }
    void validate() {
        if(host==null || !host.matches("[a-zA-Z0-9._-]+")) throw new IllegalArgumentException("Servidor inválido.");
        int portNumber=Integer.parseInt(port); if(portNumber<1 || portNumber>65535) throw new IllegalArgumentException("Porta inválida.");
        if(database==null || !database.matches("[a-zA-Z0-9_]+") || user==null || user.isBlank()) throw new IllegalArgumentException("Informe banco e usuário.");
        if(seconds<5 || seconds>86400) throw new IllegalArgumentException("Intervalo permitido: 5 a 86400 segundos.");
        directory=directory.toAbsolutePath().normalize();
    }
    void folders() throws Exception { Files.createDirectories(directory.resolve("Pendentes")); Files.createDirectories(directory.resolve("Processadas")); }
    void save() throws Exception {
        validate(); folders(); Properties p=new Properties();
        p.setProperty("host",host); p.setProperty("port",port); p.setProperty("database",database); p.setProperty("user",user);
        p.setProperty("directory",directory.toString()); p.setProperty("seconds",String.valueOf(seconds));
        p.setProperty("password.encrypted",encrypt(password));
        Path temp=Files.createTempFile(home,"config-",".tmp");
        try(var out=Files.newOutputStream(temp)){ p.store(out,"Importador Cartoes - senha AES-256-GCM"); }
        try { Files.move(temp,home.resolve("config.properties"),StandardCopyOption.REPLACE_EXISTING,StandardCopyOption.ATOMIC_MOVE); }
        catch(AtomicMoveNotSupportedException e){ Files.move(temp,home.resolve("config.properties"),StandardCopyOption.REPLACE_EXISTING); }
    }
    byte[] key(boolean create) throws Exception {
        Path file=home.resolve("secret.key");
        if(!Files.exists(file) && create){ byte[] key=new byte[32]; new SecureRandom().nextBytes(key); Files.write(file,key,StandardOpenOption.CREATE_NEW); }
        byte[] key=Files.readAllBytes(file); if(key.length!=32) throw new IllegalStateException("Chave de criptografia inválida."); return key;
    }
    String encrypt(String value) throws Exception {
        byte[] iv=new byte[12]; new SecureRandom().nextBytes(iv); Cipher c=Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.ENCRYPT_MODE,new SecretKeySpec(key(true),"AES"),new GCMParameterSpec(128,iv));
        return Base64.getEncoder().encodeToString(iv)+":"+Base64.getEncoder().encodeToString(c.doFinal(value.getBytes(StandardCharsets.UTF_8)));
    }
    String decrypt(String value) throws Exception {
        String[] parts=value.split(":"); Cipher c=Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.DECRYPT_MODE,new SecretKeySpec(key(false),"AES"),new GCMParameterSpec(128,Base64.getDecoder().decode(parts[0])));
        return new String(c.doFinal(Base64.getDecoder().decode(parts[1])),StandardCharsets.UTF_8);
    }
}
