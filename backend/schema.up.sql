-- 1. Tipe Data Enum untuk Role dan Status
CREATE TYPE user_role AS ENUM ('Petugas_Lapangan', 'Kordinator_Divisi', 'Admin');
CREATE TYPE status_observasi AS ENUM ('MENUNGGU_VERIFIKASI', 'TERVERIFIKASI', 'PERLU_DIREVISI');

-- 2. Tabel Profil Pengguna 
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  nama_lengkap TEXT NOT NULL,
  role user_role DEFAULT 'Petugas_Lapangan',
  divisi_takson TEXT, -- Contoh: 'Mamalia', 'Flora' (Khusus Kordinator)
  status_aktivitas BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Tabel Kegiatan (Program rutin/Ekspedisi)
CREATE TABLE kegiatan (
  id SERIAL PRIMARY KEY,
  nama_kegiatan TEXT NOT NULL,
  deskripsi TEXT,
  tanggal_mulai DATE,
  tanggal_selesai DATE
);

CREATE TABLE data_observasi (
  id              UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  id_petugas      UUID REFERENCES profiles(id) NOT NULL,
  id_kegiatan     INTEGER REFERENCES kegiatan(id),

  -- Data biologis
  nama_spesies    TEXT NOT NULL,
  kategori_takson TEXT NOT NULL,

  -- Data spasial & media
  latitude        DOUBLE PRECISION NOT NULL,
  longitude       DOUBLE PRECISION NOT NULL,
  foto_url        TEXT NOT NULL,

  -- Data tambahan
  catatan_habitat TEXT,
  waktu_pengamatan TIMESTAMPTZ DEFAULT NOW(),

  -- Status approval
  status_approval status_observasi DEFAULT 'MENUNGGU_VERIFIKASI',

  -- Audit verifikasi
  id_kordinator   UUID REFERENCES profiles(id),
  catatan_revisi  TEXT,
  waktu_verifikasi TIMESTAMPTZ,

  -- untuk offline sync conflict resolution
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

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


CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, nama_lengkap, role)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>('nama_lengkap'),
    'Petugas_Lapangan'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Semua user authenticated bisa lihat semua profil
CREATE POLICY "Lihat semua profil" ON profiles
  FOR SELECT USING (auth.role() = 'authenticated');

-- User hanya bisa edit profil sendiri
CREATE POLICY "Edit profil sendiri" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Admin bisa edit semua profil (misal: ubah role)
CREATE POLICY "Admin kelola profil" ON profiles
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles
             WHERE id = auth.uid() AND role = 'Admin')
  );


-- 5. Security
ALTER TABLE profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE kegiatan       ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_observasi ENABLE ROW LEVEL SECURITY;

-- 6. Policy
-- Semua bisa lihat semua observasi
CREATE POLICY "Lihat semua observasi" ON data_observasi
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Petugas tambah observasi sendiri" ON data_observasi
  FOR INSERT WITH CHECK (auth.uid() = id_petugas);

-- Petugas bisa edit/hapus observasi milik sendiri yg belum diverifikasi
CREATE POLICY "Petugas edit observasi sendiri" ON data_observasi
  FOR UPDATE USING (
    auth.uid() = id_petugas
    AND status_approval = 'MENUNGGU_VERIFIKASI'
  );

-- Kordinator/Admin bisa update status approval
CREATE POLICY "Kordinator verifikasi observasi" ON data_observasi
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND role IN ('Kordinator_Divisi', 'Admin')
    )
  );

-- Petugas hapus observasi sendiri yg belum diverifikasi
CREATE POLICY "Petugas hapus observasi sendiri" ON data_observasi
  FOR DELETE USING (
    auth.uid() = id_petugas
    AND status_approval = 'MENUNGGU_VERIFIKASI'
  );