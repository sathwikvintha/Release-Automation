package com.bnp.csc.orm.util;

import java.awt.image.BufferedImage;
import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import javax.imageio.ImageIO;

import org.apache.commons.io.FilenameUtils;
import org.apache.commons.lang.StringUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import com.bnp.csc.orm.exception.ORMApplicationException;
import com.bnp.csc.orm.service.IExportService;

import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
public class ValidateFileType {

	@Value("${mass.file.document.details.filetype}")
	private String fileSupportedFormats;
	
    private static final int BYTE_VALUE = 1024;
	
	@Autowired
	private IExportService exportService;
	
	// Magic-byte table – add more entries as required
    protected static final Map<String, byte[]> MAGIC = new LinkedHashMap<>();
	
	static {
        // PDF  – %PDF-
        MAGIC.put("application/pdf", new byte[]{0x25, 0x50, 0x44, 0x46, 0x2D});

        // PNG  – 89 50 4E 47 0D 0A 1A 0A
        MAGIC.put("image/png", new byte[]{(byte)0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A});

        // JPEG – FF D8 FF (followed by E0/E1/E8 …)
        MAGIC.put("image/jpeg", new byte[]{(byte)0xFF, (byte)0xD8, (byte)0xFF});
        
        // GIF – GIF87a or GIF89a
        MAGIC.put("image/gif", new byte[]{0x47, 0x49, 0x46, 0x38, 0x37, 0x61}); // GIF87a
        MAGIC.put("image/gif", new byte[]{0x47, 0x49, 0x46, 0x38, 0x39, 0x61}); // GIF89a

        // ZIP – 50 4B 03 04 (also used for JAR, ODT, DOCX, etc.)
        MAGIC.put("application/zip", new byte[]{0x50, 0x4B, 0x03, 0x04});

        // BMP – 42 4D
        MAGIC.put("image/bmp", new byte[]{0x42, 0x4D});

        // TIFF – 49 49 2A 00  or 4D 4D 00 2A
        MAGIC.put("image/tiff", new byte[]{0x49, 0x49, 0x2A, 0x00});
        MAGIC.put("image/tiff", new byte[]{0x4D, 0x4D, 0x00, 0x2A});

        // Add more signatures as your application needs (e.g. MP4, MP3, etc.)

        MAGIC.put("text/csv", new byte[0]);
        MAGIC.put("text/plain", new byte[0]);
    }
    
    public static final int MAX_MAGIC_BYTES   = 16;

	/**
	 * Check the File type as text/csv
	 * 
	 * @param file
	 * @throws IOException
	 * @throws ORMApplicationException
	 */
	public void checkFileTypes(MultipartFile file) throws IOException, ORMApplicationException {
		Set<String> validTypes = Arrays.stream(fileSupportedFormats.split(";")).map(String::trim)
				.collect(Collectors.toSet());
		try (InputStream docInpStream = new BufferedInputStream(file.getResource().getInputStream())) {
			String mediaType = detectMimeType(docInpStream);
			log.debug("Doc mediatype --- {}", mediaType);
			if (validTypes.contains(mediaType)) {
				log.debug("Document accepted due to valid type --- {}", file.getResource().getFilename());
			} else {
				log.debug("Document rejected due to invalid type --- {}", file.getResource().getFilename());
				throw new ORMApplicationException("File Type Not Matched..");
			}
		}
	}
	
	/**
     * Detects the MIME type by checking the first few bytes against a
     * hard‑coded signature table. If none matches we fall back to basic
     * ImageIO (covers many image formats) and finally to {@code application/octet-stream}.
     */
	private static String detectMimeType(InputStream in) throws IOException {
        // Read enough bytes for the longest signature we keep
        in.mark(MAX_MAGIC_BYTES);
        byte[] header = new byte[MAX_MAGIC_BYTES];
        int read = in.read(header);
        in.reset(); // we need the full stream later

        if (read <= 0) {
            return "application/octet-stream";
        }

        // 1️  Try the manual magicbyte table
        for (Map.Entry<String, byte[]> e : MAGIC.entrySet()) {
            byte[] sig = e.getValue();
            if (read >= sig.length && startsWith(header, sig)) {
                return e.getKey();
            }
        }

        // 2️  ImageIO can recognize many image formats (PNG, JPEG, BMP, GIF, …)
        // It consumes the stream, so we give it a fresh copy via a ByteArrayInputStream.
        try (InputStream copy = new ByteArrayInputStream(header, 0, read)) {
            BufferedImage img = ImageIO.read(copy);
            if (img != null) {
                // ImageIO does not expose the MIME directly, but we can guess from format name
                String format = ImageIO.getImageReadersBySuffix(
                        extractExtension("dummy." + img.getClass().getSimpleName()))
                        .next().getFormatName()
                        .toLowerCase(Locale.ROOT);
                switch (format) {
                    case "png":   return "image/png";
                    case "jpeg":  return "image/jpeg";
                    default:      break;
                }
            }
        } catch (Exception ignored) {
            log.error("Error while processing the file for detecting mime types due to ", ignored);
        }

        // 3️  Nothing matched → unknown binary
        return "application/octet-stream";
    }
	
	/** Returns the part after the last dot, lower‑cased, without the dot. */
    private static String extractExtension(String fileName) {
        int dot = fileName.lastIndexOf('.');
        if (dot < 0 || dot == fileName.length() - 1) {
            return "";
        }
        return fileName.substring(dot + 1).toLowerCase(Locale.ROOT);
    }
    
    /** Utility – does `data` start with `prefix`? */
    private static boolean startsWith(byte[] data, byte[] prefix) {
        if (prefix.length > data.length) {
            return false;
        }
        for (int i = 0; i < prefix.length; i++) {
            if (data[i] != prefix[i]) {
                return false;
            }
        }
        return true;
    }
	
	/**
	 * Valid file for max size
	 * 
	 * @param file
	 * @throws ORMApplicationException
	 */
	public void isValidFile(MultipartFile file) throws ORMApplicationException {
		if (null != file) {
			List<String> restrictFileTypes = new ArrayList<>(Arrays.asList("exe", "sh", "sql", "dll", "bat"));
			String fileExtn = FilenameUtils.getExtension(file.getOriginalFilename());
			if (StringUtils.isEmpty(fileExtn) || restrictFileTypes.contains(fileExtn)) {
				throw new ORMApplicationException("Filetype not acceptable.");
			}
			String maxFileSize = this.exportService.getMaxFileSizeFromParam();
			long maxGLEvidenceFileSize = Long.valueOf(maxFileSize) * BYTE_VALUE;
			log.debug("File size: {}", file.getSize());
			if (file.getSize() > maxGLEvidenceFileSize) {
				throw new ORMApplicationException("File size exceeds maxfilesize.");
			}
		}
	}
}
