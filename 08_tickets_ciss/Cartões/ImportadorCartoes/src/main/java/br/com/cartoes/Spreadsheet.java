package br.com.cartoes;

import java.nio.file.Path;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.text.Normalizer;
import java.util.*;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.ResolverStyle;
import org.apache.poi.ss.usermodel.*;

final class Spreadsheet {
    record Sale(String estabelecimento,String cnpj,String autorizacao,String nsu,String maquina,String sheet,int row,LocalDate dtmovimento,BigDecimal valorBruto) {}
    static String normalized(String s){ return Normalizer.normalize(s,Normalizer.Form.NFD).replaceAll("\\p{M}","").toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9]",""); }
    static int field(String s) {
        return switch(normalized(s)) {
            case "estabelecimento" -> 0;
            case "cpfcnpjdoestabelecimento","cnpj","cpfcnpj" -> 1;
            case "codigodeautorizacao","autorizacao" -> 2;
            case "nsudoc","nsu" -> 3;
            case "numerodamaquina","numeromaquina" -> 4;
            case "datadavenda","dtmovimento","datadomovimento" -> 5;
            case "valorbruto" -> 6;
            default -> -1;
        };
    }
    static List<Sale> read(Path path) throws Exception {
        List<Sale> result=new ArrayList<>(); boolean found=false;
        DataFormatter formatter=new DataFormatter(Locale.US); formatter.setUseCachedValuesForFormulaCells(true);
        try(Workbook wb=WorkbookFactory.create(path.toFile(),null,true)) {
            for(Sheet sheet:wb) {
                int[] columns=null;
                for(Row row:sheet) {
                    int[] candidate={-1,-1,-1,-1,-1,-1,-1};
                    for(Cell cell:row){ int f=field(formatter.formatCellValue(cell)); if(f>=0) candidate[f]=cell.getColumnIndex(); }
                    if(Arrays.stream(candidate).allMatch(v->v>=0)) {columns=candidate; found=true; continue;}
                    if(columns==null) continue;
                    String[] values=new String[5];
                    for(int i=0;i<5;i++) values[i]=formatter.formatCellValue(row.getCell(columns[i])).strip();
                    if(Arrays.stream(values).allMatch(String::isEmpty)) continue;
                    values[1]=values[1].replaceAll("[./\\-\\s]","");
                    for(int i=0;i<5;i++) {
                        if(values[i].isEmpty()) throw new IllegalArgumentException(sheet.getSheetName()+", linha "+(row.getRowNum()+1)+": campo obrigatório vazio ("+new String[]{"Estabelecimento","CNPJ","Autorização","NSU","Máquina"}[i]+").");
                        int max=new int[]{40,14,64,64,64}[i];
                        if(values[i].length()>max) throw new IllegalArgumentException("Valor excede limite na linha "+(row.getRowNum()+1));
                    }
                    if(!values[1].matches("[0-9]{14}")) throw new IllegalArgumentException("CNPJ inválido na linha "+(row.getRowNum()+1));
                    LocalDate date;
                    Cell dateCell=row.getCell(columns[5]);
                    try {
                        if(dateCell!=null && (dateCell.getCellType()==CellType.NUMERIC || (dateCell.getCellType()==CellType.FORMULA && dateCell.getCachedFormulaResultType()==CellType.NUMERIC)) && DateUtil.isCellDateFormatted(dateCell))date=dateCell.getLocalDateTimeCellValue().toLocalDate();
                        else date=LocalDate.parse(formatter.formatCellValue(dateCell).strip(),DateTimeFormatter.ofPattern("d/M/uuuu").withResolverStyle(ResolverStyle.STRICT));
                    }catch(Exception e){throw new IllegalArgumentException("Data da venda inválida na aba "+sheet.getSheetName()+", linha "+(row.getRowNum()+1),e);}
                    BigDecimal amount;
                    try {amount=amount(row.getCell(columns[6]));}
                    catch(Exception e){throw new IllegalArgumentException("Valor bruto inválido na aba "+sheet.getSheetName()+", linha "+(row.getRowNum()+1),e);}
                    result.add(new Sale(values[0],values[1],values[2],values[3],values[4],sheet.getSheetName(),row.getRowNum()+1,date,amount));
                }
            }
        }
        if(!found || result.isEmpty()) throw new IllegalArgumentException("Planilha sem cabeçalho reconhecido ou sem vendas.");
        return result;
    }
    static BigDecimal amount(Cell cell) {
        if(cell==null)throw new IllegalArgumentException("Valor bruto obrigatório.");
        CellType type=cell.getCellType()==CellType.FORMULA?cell.getCachedFormulaResultType():cell.getCellType();
        BigDecimal value;
        if(type==CellType.NUMERIC) {
            if(DateUtil.isCellDateFormatted(cell))throw new IllegalArgumentException("Valor bruto não pode ser uma data.");
            value=BigDecimal.valueOf(cell.getNumericCellValue());
        } else if(type==CellType.STRING) {
            String text=cell.getStringCellValue().strip().replaceFirst("^R\\$\\s*","").replace("\u00a0","").replace(" ","");
            if(text.contains(",")) {
                if(!text.matches("[+-]?(?:[0-9]+|[0-9]{1,3}(?:\\.[0-9]{3})+),[0-9]{1,2}"))throw new IllegalArgumentException("Formato monetário inválido.");
                text=text.replace(".","").replace(',','.');
            } else if(!text.matches("[+-]?[0-9]+(?:\\.[0-9]{1,2})?"))throw new IllegalArgumentException("Formato monetário inválido.");
            value=new BigDecimal(text);
        } else throw new IllegalArgumentException("Valor bruto obrigatório e numérico.");
        value=value.setScale(2,RoundingMode.UNNECESSARY);
        if(value.precision()>15)throw new IllegalArgumentException("Valor bruto excede DECIMAL(15,2).");
        return value;
    }
}
