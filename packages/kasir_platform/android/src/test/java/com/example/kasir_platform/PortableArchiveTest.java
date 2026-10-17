package com.example.kasir_platform;

import com.google.crypto.tink.subtle.AesGcmHkdfStreaming;
import org.junit.*;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.zip.*;
import static org.junit.Assert.*;

/** Host JVM tests exercise authenticated hostile ZIPs, rather than an auth
 * failure which never reaches the path/duplicate/member validator. Android
 * engine/Keystore/archive round trips have separate physical-device evidence.
 */
public final class PortableArchiveTest {
    private static final String CODE="ab".repeat(32);
    private Path root;
    @Before public void setUp()throws Exception{root=Files.createTempDirectory("kasir_archive_unit_").toRealPath();}
    @After public void tearDown()throws Exception{
        Path expected=Paths.get(System.getProperty("java.io.tmpdir")).toRealPath();
        if(root==null||!root.getParent().equals(expected)||!root.getFileName().toString().startsWith("kasir_archive_unit_"))throw new IOException("Refusing unowned fixture cleanup");
        try(var files=Files.walk(root)){for(Path file:files.sorted(Comparator.reverseOrder()).toList())Files.delete(file);}
    }
    private File archive(byte[] zip)throws Exception{
        File target=root.resolve(UUID.randomUUID()+".kasirbackup").toFile();
        byte[] key=new byte[32];Arrays.fill(key,(byte)0xab);
        var primitive=new AesGcmHkdfStreaming(key,"HmacSha256",32,65536,0);
        try(OutputStream output=primitive.newEncryptingStream(new FileOutputStream(target),"kasir-portable-archive-v1".getBytes(StandardCharsets.UTF_8))){output.write(zip);}
        return target;
    }
    private byte[] zip(String... names)throws Exception{
        ByteArrayOutputStream bytes=new ByteArrayOutputStream();
        try(ZipOutputStream zip=new ZipOutputStream(bytes)){
            for(String name:names){zip.putNextEntry(new ZipEntry(name));zip.write((name+" synthetic").getBytes(StandardCharsets.UTF_8));zip.closeEntry();}
        }
        return bytes.toByteArray();
    }
    private void rejected(File archive,String code,long budget)throws Exception{
        File output=root.resolve(UUID.randomUUID().toString()).toFile();
        assertThrows(Exception.class,()->PortableArchive.unpack(archive,output,code,budget));
        assertFalse("Partial extraction must be removed",output.exists());
        assertTrue("Source archive must remain",archive.exists());
    }
    @Test public void authenticatedTraversalAndUnknownMembersAreRejected()throws Exception{
        for(String name:List.of("../escape.db","/absolute.db","folder/database.db","database.db/","unexpected.txt")){
            rejected(archive(zip("manifest.json","database.db",name)),CODE,100000);
            assertFalse(root.resolve("escape.db").toFile().exists());
        }
    }
    @Test public void authenticatedDuplicateMembersAreRejected()throws Exception{
        byte[] bytes=zip("manifest.json","database.db","database.xx");
        byte[] source="database.xx".getBytes(StandardCharsets.UTF_8),replacement="database.db".getBytes(StandardCharsets.UTF_8);
        for(int at=0;at<=bytes.length-source.length;at++){
            boolean match=true;for(int i=0;i<source.length;i++)if(bytes[at+i]!=source[i]){match=false;break;}
            if(match){System.arraycopy(replacement,0,bytes,at,replacement.length);at+=source.length-1;}
        }
        rejected(archive(bytes),CODE,100000);
    }
    @Test public void wrongRecoveryAndAuthenticatedEndAreRequired()throws Exception{
        File valid=archive(zip("manifest.json","database.db"));
        rejected(valid,"cd".repeat(32),100000);
        byte[] bytes=Files.readAllBytes(valid.toPath());bytes[bytes.length-1]^=1;
        File altered=root.resolve("altered.kasirbackup").toFile();Files.write(altered.toPath(),bytes);rejected(altered,CODE,100000);
        Files.write(altered.toPath(),Arrays.copyOf(bytes,bytes.length-1));rejected(altered,CODE,100000);
    }
    @Test public void missingRequiredMemberAndStorageBudgetFailClosed()throws Exception{
        rejected(archive(zip("manifest.json")),CODE,100000);
        rejected(archive(zip("manifest.json","database.db")),CODE,4);
    }
    @Test public void existingDestinationIsRetained()throws Exception{
        File target=root.resolve("already-exists").toFile();assertTrue(target.mkdir());
        File marker=new File(target,"keep.txt");Files.write(marker.toPath(),"synthetic keep".getBytes(StandardCharsets.UTF_8));
        File input=archive(zip("manifest.json","database.db"));
        assertThrows(Exception.class,()->PortableArchive.unpack(input,target,CODE,100000));
        assertEquals("synthetic keep",new String(Files.readAllBytes(marker.toPath()),StandardCharsets.UTF_8));
    }
    @Test public void streamedRoundTripPreservesAllFixedMembers()throws Exception{
        File database=root.resolve("source.db").toFile();Files.write(database.toPath(),new byte[150000]);
        File logo=root.resolve("logo.png").toFile();Files.write(logo.toPath(),new byte[]{1,2,3});
        File archive=root.resolve("complete.kasirbackup").toFile();
        PortableArchive.pack(archive,CODE,"{\"format\":1}",Map.of("database.db",database,"logo.png",logo));
        File output=root.resolve("roundtrip").toFile();PortableArchive.unpack(archive,output,CODE,200000);
        assertEquals(150000,new File(output,"database.db").length());
        assertArrayEquals(new byte[]{1,2,3},Files.readAllBytes(new File(output,"logo.png").toPath()));
        assertEquals("{\"format\":1}",new String(Files.readAllBytes(new File(output,"manifest.json").toPath()),StandardCharsets.UTF_8));
    }
}
