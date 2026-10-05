// Copyright 2026 The DartRosa Authors
// SPDX-License-Identifier: Apache-2.0

package org.dartrosa.oracle;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import org.javarosa.core.reference.PrefixedRootFactory;
import org.javarosa.core.reference.Reference;

/** Resolves {@code jr://<scheme>/name} to {@code <dir>/name} on disk. */
final class FileReferenceFactory extends PrefixedRootFactory {
    private final File dir;

    FileReferenceFactory(String scheme, File dir) {
        super(new String[]{scheme + "/"});
        this.dir = dir;
    }

    @Override
    protected Reference factory(String terminal, String uri) {
        File file = new File(dir, terminal);
        return new Reference() {
            @Override public boolean doesBinaryExist() { return file.exists(); }
            @Override public InputStream getStream() throws IOException { return new FileInputStream(file); }
            @Override public String getURI() { return uri; }
            @Override public String getLocalURI() { return file.getAbsolutePath(); }
            @Override public boolean isReadOnly() { return true; }
            @Override public OutputStream getOutputStream() { throw new UnsupportedOperationException(); }
            @Override public void remove() { throw new UnsupportedOperationException(); }
            @Override public Reference[] probeAlternativeReferences() { return new Reference[0]; }
        };
    }
}
