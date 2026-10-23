package br.com.cartoes;

import javax.swing.*;
import javax.swing.border.EmptyBorder;
import javax.swing.event.*;
import javax.swing.table.DefaultTableModel;
import javax.swing.tree.*;
import java.awt.*;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.ResolverStyle;
import java.util.concurrent.*;
import java.util.function.*;

final class ReportPanel extends JPanel {
    static final class Group {
        final int status; final long total; boolean loaded,loading,more; long lastId; int shown;
        Group(int status,long total){this.status=status;this.total=total;}
        public String toString(){return ReportRepository.displayStatus(status)+" ("+total+")";}
    }
    final DefaultMutableTreeNode root=new DefaultMutableTreeNode("Pendentes e registros dos status 1, 2, 3 e 4");
    final DefaultTreeModel model=new DefaultTreeModel(root);
    final JTree tree=new JTree(model);
    final DefaultTableModel details=new DefaultTableModel(new String[]{"Campo","Valor"},0){public boolean isCellEditable(int r,int c){return false;}};
    final JLabel message=new JLabel("Abra esta aba para consultar os registros.");
    final JButton refresh=new JButton("Atualizar relatório"),more=new JButton("Carregar mais 100");
    final JButton recent=new JButton("Últimos 10 dias");
    final JTextField fromDate=new JTextField(10),toDate=new JTextField(10);
    final JLabel appliedPeriod=new JLabel(" ");
    static final DateTimeFormatter DATE_FORMAT=DateTimeFormatter.ofPattern("dd/MM/uuuu").withResolverStyle(ResolverStyle.STRICT);
    ReportRepository.Period activePeriod=ReportRepository.Period.lastTenDays();
    final ExecutorService worker=Executors.newSingleThreadExecutor(r->{Thread t=new Thread(r,"relatorio");t.setDaemon(true);return t;});
    final Supplier<Config> config;
    final BooleanSupplier configured;
    final Consumer<String> log;
    long generation; boolean initialized; boolean refreshing;
    ReportPanel(Supplier<Config> config,BooleanSupplier configured,Consumer<String> log){
        super(new BorderLayout(10,10));this.config=config;this.configured=configured;this.log=log;
        setBorder(new EmptyBorder(14,14,14,14));
        JPanel header=new JPanel(new BorderLayout(10,6));
        JPanel filters=new JPanel(new FlowLayout(FlowLayout.LEFT,8,0));
        filters.add(new JLabel("Data do movimento — de"));filters.add(fromDate);filters.add(new JLabel("até"));filters.add(toDate);filters.add(recent);filters.add(refresh);
        setPeriodFields(activePeriod);fromDate.setToolTipText("Data inicial inclusiva: dd/mm/aaaa");toDate.setToolTipText("Data final inclusiva: dd/mm/aaaa");
        header.add(filters,BorderLayout.NORTH);header.add(appliedPeriod,BorderLayout.SOUTH);add(header,BorderLayout.NORTH);
        tree.setRootVisible(false);tree.setShowsRootHandles(true);tree.getSelectionModel().setSelectionMode(TreeSelectionModel.SINGLE_TREE_SELECTION);
        JTable table=new JTable(details);table.setRowHeight(26);table.getColumnModel().getColumn(0).setPreferredWidth(145);table.getColumnModel().getColumn(1).setPreferredWidth(330);
        table.setAutoResizeMode(JTable.AUTO_RESIZE_OFF);table.setFillsViewportHeight(true);
        JSplitPane split=new JSplitPane(JSplitPane.HORIZONTAL_SPLIT,new JScrollPane(tree),new JScrollPane(table));split.setResizeWeight(.48);split.setDividerLocation(440);add(split);
        JPanel footer=new JPanel(new BorderLayout(10,8));footer.add(message);footer.add(more,BorderLayout.EAST);add(footer,BorderLayout.SOUTH);more.setEnabled(false);
        refresh.addActionListener(e->reload());more.addActionListener(e->{var n=selectedGroup();if(n!=null)load(n);});
        recent.addActionListener(e->{setPeriodFields(ReportRepository.Period.lastTenDays());reload();});
        fromDate.addActionListener(e->reload());toDate.addActionListener(e->reload());
        tree.addTreeWillExpandListener(new TreeWillExpandListener(){public void treeWillExpand(TreeExpansionEvent e){var n=(DefaultMutableTreeNode)e.getPath().getLastPathComponent();if(n.getUserObject() instanceof Group g && !g.loaded)load(n);}public void treeWillCollapse(TreeExpansionEvent e){}});
        tree.addTreeSelectionListener(e->selection());
    }
    void opened(){if(!initialized && !refreshing)reload();}
    void setPeriodFields(ReportRepository.Period period){fromDate.setText(DATE_FORMAT.format(period.start()));toDate.setText(DATE_FORMAT.format(period.end()));}
    void reset(){generation++;initialized=false;refreshing=false;refresh.setEnabled(true);root.removeAllChildren();model.reload();details.setRowCount(0);more.setEnabled(false);message.setText("Configuração alterada. Clique em Atualizar relatório.");}
    void reload(){
        if(!configured.getAsBoolean()){message.setText("Salve a configuração de acesso ao banco antes de consultar o relatório.");return;}
        final ReportRepository.Period period;
        try{period=new ReportRepository.Period(LocalDate.parse(fromDate.getText().strip(),DATE_FORMAT),LocalDate.parse(toDate.getText().strip(),DATE_FORMAT));}
        catch(Exception e){message.setText("Período inválido. Use dd/mm/aaaa e data inicial menor ou igual à final.");return;}
        activePeriod=period;appliedPeriod.setText("Período aplicado: "+DATE_FORMAT.format(period.start())+" a "+DATE_FORMAT.format(period.end())+" • Status 1: somente contagem. Demais grupos: expanda para consultar.");
        long token=++generation;Config snapshot=config.get();refreshing=true;refresh.setEnabled(false);more.setEnabled(false);details.setRowCount(0);root.removeAllChildren();model.reload();message.setText("Consultando totais no banco…");
        CompletableFuture.supplyAsync(()->{try{return ReportRepository.counts(snapshot,period);}catch(Exception e){throw new CompletionException(e);}},worker)
            .whenComplete((counts,failure)->SwingUtilities.invokeLater(()->{
                if(token!=generation)return;refreshing=false;refresh.setEnabled(true);
                if(failure!=null){failed(failure);return;}
                addGroup(ReportRepository.PENDING,counts.pending());addGroup(1,counts.processed());addGroup(2,counts.unchanged());addGroup(3,counts.missing());addGroup(4,counts.differentTerminal());model.reload();initialized=true;
                message.setText("Total: "+(counts.pending()+counts.processed()+counts.unchanged()+counts.missing()+counts.differentTerminal())+" registro(s), sendo "+counts.pending()+" pendente(s). Atualizado em "+java.time.LocalTime.now().withNano(0)+".");
            }));
    }
    void addGroup(int status,long total){Group group=new Group(status,total);DefaultMutableTreeNode node=new DefaultMutableTreeNode(group,status!=1);if(status==1)group.loaded=true;else node.add(new DefaultMutableTreeNode(total==0?"Nenhum registro":"Expanda para carregar os registros"));root.add(node);}
    DefaultMutableTreeNode selectedGroup(){Object selected=tree.getLastSelectedPathComponent();if(!(selected instanceof DefaultMutableTreeNode node))return null;if(node.getUserObject() instanceof Group)return node;if(node.getParent() instanceof DefaultMutableTreeNode p && p.getUserObject() instanceof Group)return p;return null;}
    void selection(){
        details.setRowCount(0);DefaultMutableTreeNode group=selectedGroup();more.setEnabled(false);if(group==null)return;
        Group g=(Group)group.getUserObject();more.setEnabled(g.loaded && g.more && !g.loading && !refreshing);
        if(g.status==1)return;
        var node=(DefaultMutableTreeNode)tree.getLastSelectedPathComponent();
        if(node.getUserObject() instanceof ReportRepository.Entry row){
            detail("ID",row.id());detail("Status",ReportRepository.displayStatus(row.status()));detail("Data do movimento",row.movimento());detail("Estabelecimento",row.estabelecimento());detail("CNPJ",row.cnpj());detail("Autorização",row.autorizacao());detail("NSU",row.nsu());detail("Valor bruto",row.valorBruto()==null?"Não informado":java.text.NumberFormat.getCurrencyInstance(java.util.Locale.forLanguageTag("pt-BR")).format(row.valorBruto()));detail("Número da máquina",row.maquina());detail("Correspondências",row.encontrados());detail("Terminais alterados",row.alterados());detail("Arquivo",row.arquivo());detail("Aba",row.aba());detail("Linha",row.linha());detail("Importado em",row.importado());detail("Processado em",row.processado());
        }else{detail("Status",g.toString());detail("Registros carregados",g.shown);detail("Total na atualização",g.total);if(!g.loaded && !g.loading)load(group);}
    }
    void detail(String name,Object value){details.addRow(new Object[]{name,value==null?"":value.toString()});}
    void load(DefaultMutableTreeNode node){
        Group g=(Group)node.getUserObject();if(g.status==1 || g.loading || (g.loaded && !g.more))return;
        if(g.total==0){g.loaded=true;g.more=false;return;}
        long token=generation;Config snapshot=config.get();ReportRepository.Period period=activePeriod;g.loading=true;more.setEnabled(false);message.setText("Carregando: "+ReportRepository.displayStatus(g.status)+"…");
        CompletableFuture.supplyAsync(()->{try{return ReportRepository.page(snapshot,g.status,g.lastId,period);}catch(Exception e){throw new CompletionException(e);}},worker)
            .whenComplete((page,failure)->SwingUtilities.invokeLater(()->{
                if(token!=generation)return;g.loading=false;
                if(failure!=null){failed(failure);more.setEnabled(selectedGroup()==node);return;}
                if(!g.loaded)node.removeAllChildren();
                for(var row:page.entries()){node.add(new DefaultMutableTreeNode(row));g.lastId=row.id();g.shown++;}
                g.loaded=true;g.more=page.hasMore();
                if(g.shown==0)node.add(new DefaultMutableTreeNode("Nenhum registro"));
                model.nodeStructureChanged(node);tree.expandPath(new TreePath(node.getPath()));
                message.setText(ReportRepository.displayStatus(g.status)+": "+g.shown+" registro(s) carregado(s)."+(g.more?" Use Carregar mais 100 para continuar.":""));
                tree.setSelectionPath(new TreePath(node.getPath()));selection();
            }));
    }
    void failed(Throwable failure){while(failure instanceof CompletionException && failure.getCause()!=null)failure=failure.getCause();String text="Falha no relatório: "+failure.getMessage();message.setText(text);message.setToolTipText(text);log.accept(text);}
    void close(){generation++;worker.shutdownNow();}
}
