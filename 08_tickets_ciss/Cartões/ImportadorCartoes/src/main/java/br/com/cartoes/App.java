package br.com.cartoes;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import java.awt.*;
import java.awt.event.*;
import java.nio.channels.*;
import java.nio.file.*;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.*;

public final class App extends JFrame {
    Config config; final Path home;
    final JTextField directory=new JTextField(),host=new JTextField(),port=new JTextField(),database=new JTextField(),user=new JTextField();
    final JPasswordField password=new JPasswordField();
    final JSpinner seconds=new JSpinner(new SpinnerNumberModel(60,5,86400,5));
    final JTextArea output=new JTextArea(); final JLabel status=new JLabel("Configure e salve para iniciar o monitoramento.");
    final JTabbedPane tabs=new JTabbedPane();
    final JButton startButton=new JButton("Iniciar scheduler"),stopButton=new JButton("Parar scheduler"),runButton=new JButton("Executar agora");
    final JLabel schedulerState=new JLabel("Scheduler parada"),cycleState=new JLabel("Nenhum ciclo executado nesta sessão."),configNotice=new JLabel(" ");
    final ReportPanel report;
    boolean configured;
    final ScheduledExecutorService worker=Executors.newSingleThreadScheduledExecutor();
    final ExecutorService connectionWorker=Executors.newCachedThreadPool(r->{Thread t=new Thread(r,"teste-conexao");t.setDaemon(true);return t;});
    ScheduledFuture<?> schedule; final Processor processor;
    static FileChannel lockChannel; static FileLock lock;
    App(Path home) throws Exception {
        super("Importador de Cartões • DB2"); this.home=home;
        var icon=App.class.getResource("/app-icon.png");
        if(icon!=null){Image source=new ImageIcon(icon).getImage();setIconImages(java.util.List.of(source.getScaledInstance(16,16,Image.SCALE_SMOOTH),source.getScaledInstance(32,32,Image.SCALE_SMOOTH),source.getScaledInstance(48,48,Image.SCALE_SMOOTH),source.getScaledInstance(256,256,Image.SCALE_SMOOTH)));}
        config=Config.load(home); processor=new Processor(this::log);
        configured=Files.exists(home.resolve("config.properties"));report=new ReportPanel(()->config,()->configured,this::log);
        setDefaultCloseOperation(DO_NOTHING_ON_CLOSE); setMinimumSize(new Dimension(900,650)); setSize(1100,760); setLocationRelativeTo(null);
        JPanel main=new JPanel(new BorderLayout(14,14)); main.setBorder(new EmptyBorder(20,24,20,24)); setContentPane(main);
        JPanel top=new JPanel(new BorderLayout()); JLabel title=new JLabel("Importação de cartões"); title.setFont(title.getFont().deriveFont(Font.BOLD,26f));
        top.add(title,BorderLayout.NORTH); top.add(new JLabel("Planilhas Excel → TMP.CARTOES_MOVIMENTO"),BorderLayout.SOUTH); main.add(top,BorderLayout.NORTH);
        main.add(tabs);
        JPanel settings=new JPanel(new BorderLayout(10,18));settings.setBorder(new EmptyBorder(18,16,18,16));
        JPanel form=new JPanel(new GridBagLayout()); settings.add(form,BorderLayout.NORTH);
        JButton browse=new JButton("Escolher…"); browse.addActionListener(e->{JFileChooser f=new JFileChooser(directory.getText());f.setFileSelectionMode(JFileChooser.DIRECTORIES_ONLY);if(f.showOpenDialog(this)==JFileChooser.APPROVE_OPTION)directory.setText(f.getSelectedFile().toString());});
        JPanel folder=new JPanel(new BorderLayout(8,0)); folder.add(directory); folder.add(browse,BorderLayout.EAST);
        field(form,0,"Diretório base",folder); field(form,1,"Servidor",host); field(form,2,"Porta",port); field(form,3,"Banco de dados",database); field(form,4,"Usuário",user); field(form,5,"Senha",password); field(form,6,"Intervalo (segundos)",seconds);
        JPanel settingsButtons=new JPanel(new FlowLayout(FlowLayout.LEFT,8,6));
        JButton save=new JButton("Salvar configurações"), test=new JButton("Testar conexão"), clear=new JButton("Limpar logs");
        for(JButton b:new JButton[]{save,test})settingsButtons.add(b);
        JPanel settingsActions=new JPanel(new BorderLayout(8,12));settingsActions.add(settingsButtons,BorderLayout.NORTH);settingsActions.add(configNotice,BorderLayout.CENTER);settings.add(settingsActions);
        JPanel monitor=new JPanel(new BorderLayout(10,12));monitor.setBorder(new EmptyBorder(16,14,14,14));
        JPanel monitorHeader=new JPanel(new BorderLayout(8,8));schedulerState.setFont(schedulerState.getFont().deriveFont(Font.BOLD,18f));monitorHeader.add(schedulerState,BorderLayout.NORTH);monitorHeader.add(cycleState,BorderLayout.CENTER);
        JPanel buttons=new JPanel(new FlowLayout(FlowLayout.LEFT,8,6));
        clear.setToolTipText("Limpa as mensagens da tela; mantém o histórico em arquivo.");
        clear.addActionListener(e->output.setText(""));
        for(JButton b:new JButton[]{startButton,stopButton,runButton,clear})buttons.add(b);
        monitorHeader.add(buttons,BorderLayout.SOUTH);monitor.add(monitorHeader,BorderLayout.NORTH);
        output.setEditable(false); output.setFont(new Font(Font.MONOSPACED,Font.PLAIN,12)); monitor.add(new JScrollPane(output));
        tabs.addTab("Configuração",settings);tabs.addTab("Monitoramento",monitor);tabs.addTab("Relatório",report);tabs.setSelectedIndex(1);
        tabs.addChangeListener(e->{if(tabs.getSelectedComponent()==report)report.opened();});
        main.add(status,BorderLayout.SOUTH);
        directory.setText(config.directory.toString()); host.setText(config.host);port.setText(config.port);database.setText(config.database);user.setText(config.user);password.setText(config.password);seconds.setValue(config.seconds);
        save.addActionListener(e->{try{Config next=read();next.save();boolean active=isRunning();config=next;configured=true;report.reset();if(active)start();else updateSchedulerControls();configNotice.setText("Configuração salva. Intervalo: "+next.seconds+" segundos."+(active?" Scheduler atualizada.":" Inicie a scheduler na aba Monitoramento."));log("Configurações salvas. Intervalo de execução: "+next.seconds+" segundos.");}catch(Exception ex){error(ex);configNotice.setText("Falha ao salvar: "+ex.getMessage());}});
        test.addActionListener(e->{try{testConnection(read(),test);}catch(Exception ex){log("Teste de conexão: "+ex.getMessage());connectionResult(false,ex.getMessage());}});
        runButton.addActionListener(e-> {Config snapshot=config;log("Execução manual solicitada.");worker.execute(()->scan(snapshot,true));});
        startButton.addActionListener(e->start());stopButton.addActionListener(e->stop());
        addWindowListener(new WindowAdapter(){public void windowClosing(WindowEvent e){
            if(schedule!=null)schedule.cancel(false);worker.shutdown();connectionWorker.shutdownNow();report.close();status.setText("Finalizando importação em andamento…");
            new Thread(()->{try{while(!worker.awaitTermination(1,TimeUnit.SECONDS)){} if(lock!=null)lock.release();lockChannel.close();}catch(Exception ignored){} SwingUtilities.invokeLater(()->{dispose();System.exit(0);});}).start();
        }});
        updateSchedulerControls();
        if(configured)start();else log("Aplicativo iniciado. Salve os dados na aba Configuração e inicie a scheduler na aba Monitoramento.");
    }
    void field(JPanel panel,int row,String text,JComponent component){GridBagConstraints g=new GridBagConstraints();g.gridy=row;g.gridx=0;g.anchor=GridBagConstraints.WEST;g.insets=new Insets(4,0,4,14);panel.add(new JLabel(text),g);g.gridx=1;g.weightx=1;g.fill=GridBagConstraints.HORIZONTAL;panel.add(component,g);}
    Config read(){Config c=new Config(home);c.directory=Path.of(directory.getText());c.host=host.getText().strip();c.port=port.getText().strip();c.database=database.getText().strip();c.user=user.getText().strip();char[] chars=password.getPassword();c.password=new String(chars);java.util.Arrays.fill(chars,'\0');c.seconds=(Integer)seconds.getValue();c.validate();return c;}
    boolean isRunning(){return schedule!=null && !schedule.isCancelled() && !schedule.isDone();}
    void updateSchedulerControls(){boolean active=isRunning();startButton.setEnabled(configured && !active);stopButton.setEnabled(active);runButton.setEnabled(configured);schedulerState.setText(active?"Scheduler em execução":"Scheduler parada");schedulerState.setForeground(active?new Color(24,120,60):new Color(110,110,110));status.setText(!configured?"Salve os dados na aba Configuração para iniciar.":(active?"Monitorando: ":"Diretório: ")+config.directory.resolve("Pendentes")+" • intervalo "+config.seconds+" s");}
    void start(){if(!configured)return;if(schedule!=null)schedule.cancel(false);Config snapshot=config;schedule=worker.scheduleWithFixedDelay(()->scan(snapshot,false),0,snapshot.seconds,TimeUnit.SECONDS);updateSchedulerControls();log("Scheduler iniciada. Intervalo: "+snapshot.seconds+" segundos.");}
    void stop(){if(schedule!=null)schedule.cancel(false);updateSchedulerControls();log("Scheduler parada. O ciclo em andamento, se houver, será concluído.");}
    void testConnection(Config c,JButton button){
        button.setEnabled(false);button.setText("Testando…");
        log("Teste de conexão iniciado: "+c.host+":"+c.port+"/"+c.database+" (limite de 15 segundos).");
        CompletableFuture.runAsync(()->{try(var connection=Database.connect(c)){}catch(Exception ex){throw new CompletionException(ex);}},connectionWorker)
            .orTimeout(15,TimeUnit.SECONDS).whenComplete((ignored,failure)->SwingUtilities.invokeLater(()->{
                button.setEnabled(true);button.setText("Testar conexão");
                Throwable cause=failure;while(cause instanceof CompletionException && cause.getCause()!=null)cause=cause.getCause();
                String message=cause==null?"Conexão DB2 estabelecida com sucesso.":cause instanceof TimeoutException?"Tempo limite de 15 segundos excedido. Verifique servidor, porta e rede.":"Falha ao conectar: "+cause.getMessage();
                log("Teste de conexão: "+message);connectionResult(cause==null,message);
            }));
    }
    void connectionResult(boolean success,String message){JOptionPane.showMessageDialog(this,message,"Teste de conexão",success?JOptionPane.INFORMATION_MESSAGE:JOptionPane.ERROR_MESSAGE);}
    void scan(Config c,boolean manual){
        long started=System.nanoTime();log("Ciclo "+(manual?"manual":"automático")+" iniciado. Verificando "+c.directory.resolve("Pendentes"));
        SwingUtilities.invokeLater(()->cycleState.setText("Ciclo "+(manual?"manual":"automático")+" em execução desde "+LocalDateTime.now().format(DateTimeFormatter.ofPattern("HH:mm:ss"))+"."));
        try{processor.scan(c,manual);}catch(Exception ex){error(ex);}
        finally{long elapsed=TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-started);log("Ciclo "+(manual?"manual":"automático")+" finalizado em "+elapsed+" ms.");SwingUtilities.invokeLater(()->cycleState.setText("Último ciclo finalizado em "+LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss"))+" • duração "+elapsed+" ms."));}
    }
    synchronized void log(String text){String line=LocalDateTime.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm:ss"))+" | "+text+System.lineSeparator();SwingUtilities.invokeLater(()->{output.append(line);if(output.getDocument().getLength()>150000)output.replaceRange("",0,50000);output.setCaretPosition(output.getDocument().getLength());});try{Files.createDirectories(home.resolve("logs"));Files.writeString(home.resolve("logs/importador-"+java.time.LocalDate.now()+".log"),line,StandardOpenOption.CREATE,StandardOpenOption.APPEND);}catch(Exception ex){SwingUtilities.invokeLater(()->status.setText("Falha ao gravar log: "+ex.getMessage()));}}
    void error(Exception ex){log("ERRO: "+ex.getMessage());}
    public static void main(String[] args) throws Exception {
        if(args.length>0){Cli.main(args);return;}
        Path home=Config.home();Files.createDirectories(home);lockChannel=FileChannel.open(home.resolve("importador.lock"),StandardOpenOption.CREATE,StandardOpenOption.WRITE);lock=lockChannel.tryLock();
        if(lock==null){JOptionPane.showMessageDialog(null,"O aplicativo já está aberto neste diretório.");return;}
        UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
        SwingUtilities.invokeLater(()->{try{new App(home).setVisible(true);}catch(Exception e){JOptionPane.showMessageDialog(null,"Não foi possível iniciar: "+e.getMessage());System.exit(1);}});
    }
}
