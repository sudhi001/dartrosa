// Copyright 2026 The DartRosa Authors
// Derived from ODK Collect (EncryptionUtils), Copyright (C) 2011 University of
//  Washington; modified: Android removed, randomness made deterministic.
// SPDX-License-Identifier: Apache-2.0

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.*;
import java.security.spec.X509EncodedKeySpec;
import java.math.BigInteger;
import java.util.*;
import javax.crypto.*;
import javax.crypto.spec.*;
import org.kxml2.io.KXmlSerializer;
import org.kxml2.kdom.*;

/** Collect's EncryptionUtils logic, minus Android, with deterministic randomness. */
public class Golden {
  static final String ASYM = "RSA/NONE/OAEPWithSHA256AndMGF1Padding";
  static final String SYM = "AES/CFB/PKCS5Padding";
  static final String NS = "http://www.opendatakit.org/xforms/encrypted";
  static final String ORX = "http://openrosa.org/xforms";

  static class CounterRandom extends SecureRandom {
    int next;
    CounterRandom(int start) { next = start; }
    @Override public void nextBytes(byte[] b) { for (int i = 0; i < b.length; i++) b[i] = (byte) (next++); }
  }

  static String md5Hex(byte[] data) throws Exception {
    MessageDigest md = MessageDigest.getInstance("MD5");
    StringBuilder s = new StringBuilder(new BigInteger(1, md.digest(data)).toString(16));
    while (s.length() < 32) s.insert(0, "0");
    return s.toString();
  }

  public static void main(String[] a) throws Exception {
    Security.addProvider(new org.bouncycastle.jce.provider.BouncyCastleProvider());
    // args: outDir pubB64 seed formId version(-) instanceId submissionFile [mediaFile...]
    Path out = Paths.get(a[0]);
    Files.createDirectories(out);
    String pubB64 = a[1].trim();
    CounterRandom r = new CounterRandom(Integer.parseInt(a[2]));
    String formId = a[3];
    String formVersion = a[4].equals("-") ? null : a[4];
    String instanceId = a[5];
    File submission = new File(a[6]);
    List<File> media = new ArrayList<>();
    for (int i = 7; i < a.length; i++) media.add(new File(a[i]));

    PublicKey pk = KeyFactory.getInstance("RSA").generatePublic(new X509EncodedKeySpec(Base64.getDecoder().decode(pubB64)));
    byte[] key = new byte[32];
    r.nextBytes(key);
    SecretKeySpec symmetricKey = new SecretKeySpec(key, SYM);
    MessageDigest md = MessageDigest.getInstance("MD5");
    md.update(instanceId.getBytes("UTF-8"));
    md.update(key);
    byte[] ivSeedArray = Arrays.copyOf(md.digest(), 16);
    Cipher pkCipher = Cipher.getInstance(ASYM, "BC");
    pkCipher.init(Cipher.ENCRYPT_MODE, pk, r);
    String encKey = Base64.getEncoder().encodeToString(pkCipher.doFinal(key));
    StringBuilder sig = new StringBuilder();
    sig.append(formId).append('\n');
    if (formVersion != null) sig.append(formVersion).append('\n');
    sig.append(encKey).append('\n');
    sig.append(instanceId).append('\n');

    int ivCounter = 0;
    List<File> all = new ArrayList<>(media);
    all.add(submission);
    for (File f : all) {
      byte[] data = Files.readAllBytes(f.toPath());
      sig.append(f.getName() + "::" + md5Hex(data)).append('\n');
      ++ivSeedArray[ivCounter % ivSeedArray.length];
      ++ivCounter;
      Cipher c = Cipher.getInstance(SYM, "BC");
      c.init(Cipher.ENCRYPT_MODE, symmetricKey, new IvParameterSpec(ivSeedArray));
      ByteArrayOutputStream bos = new ByteArrayOutputStream();
      CipherOutputStream cos = new CipherOutputStream(bos, c);
      cos.write(data);
      cos.flush();
      cos.close();
      Files.write(out.resolve(f.getName() + ".enc"), bos.toByteArray());
    }
    byte[] sigMd5 = MessageDigest.getInstance("MD5").digest(sig.toString().getBytes("UTF-8"));
    pkCipher = Cipher.getInstance(ASYM, "BC");
    pkCipher.init(Cipher.ENCRYPT_MODE, pk, r);
    String encSig = Base64.getEncoder().encodeToString(pkCipher.doFinal(sigMd5));

    Document d = new Document();
    d.setStandalone(true);
    d.setEncoding("UTF-8");
    Element e = d.createElement(NS, "data");
    e.setPrefix(null, NS);
    e.setAttribute(null, "id", formId);
    if (formVersion != null) e.setAttribute(null, "version", formVersion);
    e.setAttribute(null, "encrypted", "yes");
    d.addChild(0, Node.ELEMENT, e);
    int idx = 0;
    Element c = d.createElement(NS, "base64EncryptedKey");
    c.addChild(0, Node.TEXT, encKey);
    e.addChild(idx++, Node.ELEMENT, c);
    c = d.createElement(ORX, "meta");
    c.setPrefix("orx", ORX);
    Element it = d.createElement(ORX, "instanceID");
    it.addChild(0, Node.TEXT, instanceId);
    c.addChild(0, Node.ELEMENT, it);
    e.addChild(idx++, Node.ELEMENT, c);
    e.addChild(idx++, Node.IGNORABLE_WHITESPACE, "\n");
    for (File f : media) {
      c = d.createElement(NS, "media");
      Element ft = d.createElement(NS, "file");
      ft.addChild(0, Node.TEXT, f.getName() + ".enc");
      c.addChild(0, Node.ELEMENT, ft);
      e.addChild(idx++, Node.ELEMENT, c);
      e.addChild(idx++, Node.IGNORABLE_WHITESPACE, "\n");
    }
    c = d.createElement(NS, "encryptedXmlFile");
    c.addChild(0, Node.TEXT, submission.getName() + ".enc");
    e.addChild(idx++, Node.ELEMENT, c);
    c = d.createElement(NS, "base64EncryptedElementSignature");
    c.addChild(0, Node.TEXT, encSig);
    e.addChild(idx, Node.ELEMENT, c);
    FileOutputStream fout = new FileOutputStream(out.resolve("manifest.xml").toFile());
    KXmlSerializer serializer = new KXmlSerializer();
    serializer.setOutput(fout, "UTF-8");
    d.writeChildren(serializer);
    serializer.flush();
    fout.close();
    Files.write(out.resolve("signature-source.txt"), sig.toString().getBytes("UTF-8"));
  }
}
