-- ============================================================
-- E-HUTAN DATABASE SCHEMA
-- ============================================================

-- 1. Tipe Data Enum
CREATE TYPE user_role AS ENUM ('Petugas_Lapangan', 'Kordinator_Divisi', 'Admin');
CREATE TYPE status_observasi AS ENUM ('MENUNGGU_VERIFIKASI', 'TERVERIFIKASI', 'PERLU_DIREVISI');

-- ============================================================
-- 2. Tabel Profil Pengguna
-- ============================================================
CREATE TABLE profiles (
  id               UUID REFERENCES auth.users(id) PRIMARY KEY,
  nama_lengkap     TEXT NOT NULL,
  role             user_role DEFAULT 'Petugas_Lapangan',
  divisi_takson    TEXT,
  status_aktivitas BOOLEAN DEFAULT true,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. Tabel Kegiatan
-- ============================================================
CREATE TABLE kegiatan (
  id              SERIAL PRIMARY KEY,
  nama_kegiatan   TEXT NOT NULL,
  deskripsi       TEXT,
  tanggal_mulai   DATE,
  tanggal_selesai DATE
);

-- ============================================================
-- 4. Tabel Data Observasi
-- ============================================================
CREATE TABLE data_observasi (
  id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  id_petugas       UUID REFERENCES profiles(id) NOT NULL,
  id_kegiatan      INTEGER REFERENCES kegiatan(id),

  -- Data biologis
  nama_spesies     TEXT NOT NULL,
  kategori_takson  TEXT NOT NULL,

  -- Data spasial & media
  latitude         DOUBLE PRECISION NOT NULL,
  longitude        DOUBLE PRECISION NOT NULL,

  -- foto_url menyimpan storage path: observasi/{user_id}/{uuid}.ext
  -- Contoh: 'observasi/abc-123/xyz-456.jpg'
  -- Generate URL dengan: supabase.storage.from('Foto_Observasi').getPublicUrl(foto_url)
  foto_url         TEXT NOT NULL,

  -- Data tambahan
  catatan_habitat  TEXT,
  waktu_pengamatan TIMESTAMPTZ DEFAULT NOW(),

  -- Status approval
  status_approval  status_observasi DEFAULT 'MENUNGGU_VERIFIKASI',

  -- Audit verifikasi
  id_kordinator    UUID REFERENCES profiles(id),
  catatan_revisi   TEXT,
  waktu_verifikasi TIMESTAMPTZ,

  -- Offline sync conflict resolution
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. Triggers
-- ============================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_observasi_updated_at
  BEFORE UPDATE ON data_observasi
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Auto-create profile saat user baru register
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, nama_lengkap, role)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'nama_lengkap',
    'Petugas_Lapangan'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 6. Enable Row Level Security
-- ============================================================
ALTER TABLE profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE kegiatan       ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_observasi ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 7. Policies: profiles
-- ============================================================
CREATE POLICY "Lihat semua profil" ON profiles
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Edit profil sendiri" ON profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admin kelola profil" ON profiles
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- ============================================================
-- 8. Policies: kegiatan  ← BARU (sebelumnya tidak ada!)
-- ============================================================
CREATE POLICY "Semua bisa lihat kegiatan" ON kegiatan
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admin kelola kegiatan" ON kegiatan
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- ============================================================
-- 9. Policies: data_observasi
-- ============================================================
CREATE POLICY "Lihat semua observasi" ON data_observasi
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Petugas tambah observasi sendiri" ON data_observasi
  FOR INSERT WITH CHECK (auth.uid() = id_petugas);

CREATE POLICY "Petugas edit observasi sendiri" ON data_observasi
  FOR UPDATE USING (
    auth.uid() = id_petugas
    AND status_approval = 'MENUNGGU_VERIFIKASI'
  );

CREATE POLICY "Kordinator verifikasi observasi" ON data_observasi
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND role IN ('Kordinator_Divisi', 'Admin')
    )
  );

CREATE POLICY "Petugas hapus observasi sendiri" ON data_observasi
  FOR DELETE USING (
    auth.uid() = id_petugas
    AND status_approval = 'MENUNGGU_VERIFIKASI'
  );

-- ============================================================
-- 10. Storage Policies: Foto_Observasi  
-- ============================================================
CREATE POLICY "Petugas upload foto observasi"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'Foto_Observasi'
  AND auth.role() = 'authenticated'
);

CREATE POLICY "User authenticated bisa lihat foto"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'Foto_Observasi'
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Petugas hapus foto milik sendiri"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'Foto_Observasi'
  AND auth.uid()::text = (storage.foldername(name))[2]
);

- ============================================================
-- Tambahan
-- ============================================================

-- 1. Pembuatan Tipe Data Enum untuk Divisi
-- Digunakan untuk memastikan konsistensi nama divisi di seluruh tabel.
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipe_divisi') THEN
        CREATE TYPE tipe_divisi AS ENUM (
            'DK Karnivora', 
            'DK Herbivora', 
            'DK Primata', 
            'DK Burung', 
            'DK Reptil Amfibi', 
            'DK Insekta', 
            'DK Fauna Perairan', 
            'DK Eksitu'
        );
    END IF;
END $$;

-- 2. Update Tabel Profiles
-- Mengubah kolom 'divisi_takson' dari TEXT menjadi ENUM tipe_divisi.
ALTER TABLE profiles 
  ALTER COLUMN divisi_takson TYPE tipe_divisi 
  USING divisi_takson::tipe_divisi;

COMMENT ON COLUMN profiles.divisi_takson IS 'Menentukan spesialisasi kordinator atau petugas lapangan';

-- 3. Update Tabel Data Observasi
-- Mengubah kolom 'kategori_takson' menjadi ENUM agar sinkron dengan divisi.
-- Ini mencegah kesalahan input kategori yang tidak terdaftar di divisi resmi.
ALTER TABLE data_observasi 
  ALTER COLUMN kategori_takson TYPE tipe_divisi 
  USING kategori_takson::tipe_divisi;

COMMENT ON COLUMN data_observasi.kategori_takson IS 'Kategori flora/fauna yang harus sesuai dengan daftar divisi resmi';

-- 4. Pembaruan Row Level Security (RLS) untuk Verifikasi
-- Koordinator hanya boleh memverifikasi data yang masuk ke dalam divisinya sendiri.
-- Admin tetap memiliki akses ke semua data.

-- Hapus kebijakan lama jika ada
DROP POLICY IF EXISTS "Kordinator verifikasi observasi" ON data_observasi;
DROP POLICY IF EXISTS "Kordinator verifikasi sesuai divisi" ON data_observasi;

-- Terapkan kebijakan baru yang lebih ketat
CREATE POLICY "Kordinator verifikasi sesuai divisi" ON data_observasi
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND (
          role = 'Admin' -- Admin bisa segalanya
          OR (
            role = 'Kordinator_Divisi' 
            AND divisi_takson = data_observasi.kategori_takson -- Cek kecocokan divisi
          )
        )
    )
  );

-- 5. Tambahan: Indexing untuk Performa
-- Karena kita akan sering memfilter data berdasarkan divisi (kategori_takson),
-- penambahan index akan mempercepat query saat data sudah banyak.
CREATE INDEX IF NOT EXISTS idx_observasi_kategori ON data_observasi(kategori_takson);
CREATE INDEX IF NOT EXISTS idx_profiles_divisi ON profiles(divisi_takson);