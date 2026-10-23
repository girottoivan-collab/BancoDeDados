import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.*;
import java.nio.file.*;
import java.util.*;
import javax.imageio.ImageIO;

/** Converte a imagem fornecida, sem cortes, em PNG e ICO com multiplos tamanhos. */
public class PrepareIcon {
    public static void main(String[] args) throws Exception {
        BufferedImage original=ImageIO.read(Path.of(args[0]).toFile());
        if(original==null)throw new IOException("Formato de imagem não reconhecido.");
        Path png=Path.of(args[1]),ico=Path.of(args[2]);
        Files.createDirectories(png.toAbsolutePath().getParent());
        ImageIO.write(original,"png",png.toFile());
        int[] sizes={16,24,32,48,64,128,256};
        java.util.List<byte[]> frames=new ArrayList<>();
        for(int size:sizes){
            BufferedImage frame=new BufferedImage(size,size,BufferedImage.TYPE_INT_ARGB);
            Graphics2D g=frame.createGraphics();
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION,RenderingHints.VALUE_INTERPOLATION_BICUBIC);
            double scale=Math.min((double)size/original.getWidth(),(double)size/original.getHeight());
            int width=(int)Math.round(original.getWidth()*scale),height=(int)Math.round(original.getHeight()*scale);
            g.drawImage(original,(size-width)/2,(size-height)/2,width,height,null);g.dispose();
            ByteArrayOutputStream data=new ByteArrayOutputStream();ImageIO.write(frame,"png",data);frames.add(data.toByteArray());
        }
        int offset=6+16*sizes.length;
        ByteBuffer header=ByteBuffer.allocate(offset).order(ByteOrder.LITTLE_ENDIAN);
        header.putShort((short)0).putShort((short)1).putShort((short)sizes.length);
        for(int i=0;i<sizes.length;i++){
            int dimension=sizes[i]==256?0:sizes[i];byte[] bytes=frames.get(i);
            header.put((byte)dimension).put((byte)dimension).put((byte)0).put((byte)0);
            header.putShort((short)1).putShort((short)32).putInt(bytes.length).putInt(offset);offset+=bytes.length;
        }
        try(OutputStream out=Files.newOutputStream(ico)){out.write(header.array());for(byte[] frame:frames)out.write(frame);}
        System.out.println("Ícone gerado: "+original.getWidth()+"x"+original.getHeight()+"; ICO de 16 a 256 pixels.");
    }
}
