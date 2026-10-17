package com.example.kasir_platform;

import com.google.crypto.tink.subtle.AesGcmHkdfStreaming;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.zip.*;

/** ZIP is streamed inside Tink AEAD: neither a plaintext database nor a
 * plaintext ZIP is written. Extraction authenticates through EOF before its
 * directory is returned; fixed member names and byte budgets prevent traversal
 * and decompression bombs. Untrusted file names never become filesystem paths.
 */
final class PortableArchive {
    private static final byte[] AAD = "kasir-portable-archive-v1".getBytes(StandardCharsets.UTF_8);
    private static final Set<String> NAMES = Set.of("manifest.json","database.db","logo.png");
    private static AesGcmHkdfStreaming primitive(String hex) throws Exception {
        if (hex == null || !hex.matches("[0-9a-fA-F]{64}")) throw new IOException("Invalid recovery code");
        byte[] key = new byte[32];
        for (int i=0;i<32;i++) key[i]=(byte)Integer.parseInt(hex.substring(i*2,i*2+2),16);
        try { return new AesGcmHkdfStreaming(key,"HmacSha256",32,65536,0); }
        finally { Arrays.fill(key,(byte)0); }
    }
    static void pack(File output, String key, String manifest, Map<String,File> files) throws Exception {
        if (output.exists() || manifest.getBytes(StandardCharsets.UTF_8).length>65536 ||
            !files.containsKey("database.db") || files.containsKey("manifest.json") || !NAMES.containsAll(files.keySet())) throw new IOException("Invalid archive members");
        try (FileOutputStream file=new FileOutputStream(output);
             OutputStream encrypted=primitive(key).newEncryptingStream(file,AAD);
             ZipOutputStream zip=new ZipOutputStream(encrypted)) {
            zip.putNextEntry(new ZipEntry("manifest.json"));
            zip.write(manifest.getBytes(StandardCharsets.UTF_8)); zip.closeEntry();
            byte[] buffer=new byte[65536];
            for (Map.Entry<String,File> member:files.entrySet()) {
                zip.putNextEntry(new ZipEntry(member.getKey()));
                try (InputStream source=new FileInputStream(member.getValue())) {
                    int n;while((n=source.read(buffer))!=-1) zip.write(buffer,0,n);
                }
                zip.closeEntry();
            }
            Arrays.fill(buffer,(byte)0);
        } catch(Exception error) { output.delete();throw error; }
        try(RandomAccessFile file=new RandomAccessFile(output,"rw")){file.getFD().sync();}
    }
    static void unpack(File input, File output, String key, long budget) throws Exception {
        if (output.exists() || budget<1 || !output.mkdirs()) throw new IOException("Extraction staging unavailable");
        Set<String> found=new HashSet<>();long total=0;
        try (InputStream file=new FileInputStream(input);
             InputStream decrypted=primitive(key).newDecryptingStream(file,AAD);
             ZipInputStream zip=new ZipInputStream(decrypted)) {
            byte[] buffer=new byte[65536];ZipEntry entry;
            while((entry=zip.getNextEntry())!=null) {
                String name=entry.getName();
                if (!NAMES.contains(name) || entry.isDirectory() || !found.add(name)) throw new IOException("Invalid archive member");
                long length=0;
                try(FileOutputStream target=new FileOutputStream(new File(output,name))) {
                    int n;while((n=zip.read(buffer))!=-1) {
                        length+=n;total+=n;
                        if(total>budget || (name.equals("manifest.json") && length>65536) ||
                            (name.equals("logo.png") && length>4194304)) throw new IOException("Archive size budget exceeded");
                        target.write(buffer,0,n);
                    }
                    target.getFD().sync();
                }
                zip.closeEntry();
            }
            if(!found.containsAll(Set.of("manifest.json","database.db"))) throw new IOException("Incomplete archive");
            // ZIP reaches its central directory before the encrypted stream's
            // authenticated final segment. Drain it, never accept early EOF.
            while(decrypted.read(buffer)!=-1) {}
            Arrays.fill(buffer,(byte)0);
        } catch(Exception error) {
            for(String name:NAMES) new File(output,name).delete();
            output.delete();throw error;
        }
    }
}
